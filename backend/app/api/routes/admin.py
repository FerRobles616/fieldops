import uuid
from typing import Annotated

from fastapi import APIRouter, Header, HTTPException, status
from sqlalchemy import select

from app.api.deps import AdminUser, DbSession
from app.models.processed_operation import ProcessedOperation
from app.models.user import User, UserRole
from app.schemas.auth import UserRead
from app.schemas.work_order import WorkOrderAssign, WorkOrderRead
from app.services.work_orders import (
    apply_work_order_update,
    get_technician_or_404,
    get_work_order_or_404,
)

router = APIRouter(prefix="/admin", tags=["admin"])


@router.get("/ping")
def admin_ping(_current_user: AdminUser) -> dict[str, str]:
    return {"status": "admin-only"}


@router.get("/technicians", response_model=list[UserRead])
def list_technicians(
    db: DbSession,
    _current_user: AdminUser,
) -> list[UserRead]:
    technicians = db.scalars(
        select(User).where(User.role == UserRole.TECHNICIAN).order_by(User.name)
    ).all()
    return [UserRead.model_validate(user) for user in technicians]


@router.patch(
    "/work-orders/{work_order_id}/assign",
    response_model=WorkOrderRead,
)
def assign_work_order(
    work_order_id: uuid.UUID,
    payload: WorkOrderAssign,
    db: DbSession,
    _current_user: AdminUser,
    idempotency_key: Annotated[
        uuid.UUID | None,
        Header(alias="Idempotency-Key"),
    ] = None,
) -> WorkOrderRead:
    if idempotency_key is not None:
        existing_operation = db.get(ProcessedOperation, idempotency_key)
        if existing_operation is not None:
            if existing_operation.work_order_id != work_order_id:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=("Idempotency key reused for a different work order"),
                )
            return WorkOrderRead.model_validate(existing_operation.response_json)

    work_order = get_work_order_or_404(db, work_order_id)
    technician = get_technician_or_404(db, payload.assigned_to)
    updated = apply_work_order_update(
        db,
        work_order,
        {"assigned_to_id": technician.id},
        payload.base_version,
        idempotency_key=idempotency_key,
    )
    return WorkOrderRead.model_validate(updated)
