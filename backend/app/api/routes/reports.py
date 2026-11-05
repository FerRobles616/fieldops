import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, Response
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.models.work_order_photo import WorkOrderPhoto
from app.services.pdf import generate_work_order_pdf
from app.services.storage import StorageService, get_storage_service
from app.services.work_orders import ensure_can_view, get_work_order_or_404

router = APIRouter(prefix="/work-orders", tags=["reports"])


@router.get("/{work_order_id}/report.pdf")
def download_report(
    work_order_id: uuid.UUID,
    db: DbSession,
    current_user: CurrentUser,
    storage: Annotated[StorageService, Depends(get_storage_service)],
) -> Response:
    work_order = get_work_order_or_404(db, work_order_id)
    ensure_can_view(work_order, current_user)

    photos = db.scalars(
        select(WorkOrderPhoto)
        .where(WorkOrderPhoto.work_order_id == work_order_id)
        .order_by(WorkOrderPhoto.created_at.asc())
    ).all()

    pdf = generate_work_order_pdf(
        work_order,
        list(photos),
        storage,
    )
    return Response(
        content=pdf,
        media_type="application/pdf",
        headers={"Content-Disposition": (f'attachment; filename="{work_order.code}.pdf"')},
    )
