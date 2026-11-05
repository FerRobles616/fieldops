import uuid
from datetime import UTC, datetime
from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    File,
    Form,
    Header,
    HTTPException,
    Response,
    UploadFile,
    status,
)
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.core.config import get_settings
from app.models.processed_operation import ProcessedOperation
from app.models.work_order_photo import WorkOrderPhoto
from app.schemas.work_order_photo import WorkOrderPhotoRead
from app.services.storage import StorageService, get_storage_service
from app.services.work_orders import ensure_can_view, get_work_order_or_404

router = APIRouter(prefix="/work-orders", tags=["photos"])

_EXTENSIONS = {
    "image/jpeg": "jpg",
    "image/png": "png",
    "image/webp": "webp",
}


def _photo_read(photo: WorkOrderPhoto) -> WorkOrderPhotoRead:
    return WorkOrderPhotoRead(
        id=photo.id,
        work_order_id=photo.work_order_id,
        caption=photo.caption,
        content_type=photo.content_type,
        file_size=photo.file_size,
        created_at=photo.created_at,
        download_url=(f"/work-orders/{photo.work_order_id}/photos/{photo.id}/file"),
    )


@router.post(
    "/{work_order_id}/photos",
    response_model=WorkOrderPhotoRead,
    status_code=status.HTTP_201_CREATED,
)
async def upload_photo(
    work_order_id: uuid.UUID,
    db: DbSession,
    current_user: CurrentUser,
    storage: Annotated[StorageService, Depends(get_storage_service)],
    file: Annotated[UploadFile, File()],
    caption: Annotated[str | None, Form(max_length=255)] = None,
    idempotency_key: Annotated[
        uuid.UUID | None,
        Header(alias="Idempotency-Key"),
    ] = None,
) -> WorkOrderPhotoRead:
    if idempotency_key is not None:
        existing_operation = db.get(ProcessedOperation, idempotency_key)
        if existing_operation is not None:
            if existing_operation.work_order_id != work_order_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=("Idempotency key reused for a different work order"),
                )
            return WorkOrderPhotoRead.model_validate(existing_operation.response_json)

    work_order = get_work_order_or_404(db, work_order_id)
    ensure_can_view(work_order, current_user)

    settings = get_settings()
    content_type = (file.content_type or "").lower()
    if content_type == "image/jpg":
        content_type = "image/jpeg"
    if content_type not in settings.allowed_photo_type_set:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail="Unsupported photo type. Use JPEG, PNG, or WebP.",
        )

    data = await file.read(settings.upload_max_bytes + 1)
    if len(data) > settings.upload_max_bytes:
        raise HTTPException(
            status_code=status.HTTP_413_CONTENT_TOO_LARGE,
            detail="Photo is too large",
        )
    if not data:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="Photo is empty",
        )

    photo_id = uuid.uuid4()
    extension = _EXTENSIONS[content_type]
    storage_key = f"work-orders/{work_order_id}/{photo_id}.{extension}"
    storage.save(storage_key, data)

    photo = WorkOrderPhoto(
        id=photo_id,
        work_order_id=work_order_id,
        storage_key=storage_key,
        content_type=content_type,
        file_size=len(data),
        caption=caption,
        uploaded_by_id=current_user.id,
        created_at=datetime.now(UTC),
    )
    db.add(photo)
    response = _photo_read(photo)

    if idempotency_key is not None:
        db.add(
            ProcessedOperation(
                op_id=idempotency_key,
                work_order_id=work_order_id,
                response_json=response.model_dump(mode="json"),
            )
        )

    try:
        db.commit()
    except Exception:
        db.rollback()
        storage.delete(storage_key)
        raise

    return response


@router.get(
    "/{work_order_id}/photos",
    response_model=list[WorkOrderPhotoRead],
)
def list_photos(
    work_order_id: uuid.UUID,
    db: DbSession,
    current_user: CurrentUser,
) -> list[WorkOrderPhotoRead]:
    work_order = get_work_order_or_404(db, work_order_id)
    ensure_can_view(work_order, current_user)

    photos = db.scalars(
        select(WorkOrderPhoto)
        .where(WorkOrderPhoto.work_order_id == work_order_id)
        .order_by(WorkOrderPhoto.created_at.desc())
    ).all()
    return [_photo_read(photo) for photo in photos]


@router.get("/{work_order_id}/photos/{photo_id}/file")
def download_photo(
    work_order_id: uuid.UUID,
    photo_id: uuid.UUID,
    db: DbSession,
    current_user: CurrentUser,
    storage: Annotated[StorageService, Depends(get_storage_service)],
) -> Response:
    work_order = get_work_order_or_404(db, work_order_id)
    ensure_can_view(work_order, current_user)

    photo = db.scalar(
        select(WorkOrderPhoto).where(
            WorkOrderPhoto.id == photo_id,
            WorkOrderPhoto.work_order_id == work_order_id,
        )
    )
    if photo is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Photo not found",
        )

    content = storage.read(photo.storage_key)
    extension = photo.content_type.split("/")[-1]
    return Response(
        content=content,
        media_type=photo.content_type,
        headers={"Content-Disposition": (f'inline; filename="{photo.id}.{extension}"')},
    )
