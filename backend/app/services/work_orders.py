import uuid
from datetime import UTC, datetime
from typing import Any

from fastapi import HTTPException, status
from sqlalchemy import ColumnElement, func, or_, select, update
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.processed_operation import ProcessedOperation
from app.models.user import User, UserRole
from app.models.work_order import WorkOrder, WorkOrderPriority, WorkOrderStatus
from app.schemas.work_order import WorkOrderRead


def get_work_order_or_404(db: Session, work_order_id: uuid.UUID) -> WorkOrder:
    work_order = db.scalar(
        select(WorkOrder)
        .where(WorkOrder.id == work_order_id, WorkOrder.deleted_at.is_(None))
        .execution_options(populate_existing=True)
    )
    if work_order is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Work order not found",
        )
    return work_order


def get_customer_or_404(db: Session, customer_id: uuid.UUID) -> Customer:
    customer = db.get(Customer, customer_id)
    if customer is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Customer not found",
        )
    return customer


def get_technician_or_404(db: Session, user_id: uuid.UUID) -> User:
    user = db.get(User, user_id)
    if user is None or user.role != UserRole.TECHNICIAN:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Technician not found",
        )
    return user


def ensure_can_view(work_order: WorkOrder, user: User) -> None:
    if user.role == UserRole.ADMIN:
        return
    if work_order.assigned_to_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Work order not found",
        )


def list_work_orders(
    db: Session,
    user: User,
    *,
    status_filter: WorkOrderStatus | None = None,
    priority_filter: WorkOrderPriority | None = None,
    query: str | None = None,
    limit: int = 20,
    offset: int = 0,
) -> tuple[list[WorkOrder], int]:
    conditions: list[ColumnElement[bool]] = [WorkOrder.deleted_at.is_(None)]

    if user.role == UserRole.TECHNICIAN:
        conditions.append(WorkOrder.assigned_to_id == user.id)
    if status_filter is not None:
        conditions.append(WorkOrder.status == status_filter)
    if priority_filter is not None:
        conditions.append(WorkOrder.priority == priority_filter)
    if query:
        pattern = f"%{query.strip()}%"
        conditions.append(
            or_(
                WorkOrder.code.ilike(pattern),
                WorkOrder.title.ilike(pattern),
            )
        )

    total = db.scalar(select(func.count()).select_from(WorkOrder).where(*conditions)) or 0
    items = list(
        db.scalars(
            select(WorkOrder)
            .where(*conditions)
            .order_by(WorkOrder.created_at.desc())
            .limit(limit)
            .offset(offset)
        ).all()
    )
    return items, total


def apply_work_order_update(
    db: Session,
    work_order: WorkOrder,
    values: dict[str, Any],
    base_version: int,
    *,
    idempotency_key: uuid.UUID | None = None,
) -> WorkOrder:
    now = datetime.now(UTC)
    result = db.execute(
        update(WorkOrder)
        .where(
            WorkOrder.id == work_order.id,
            WorkOrder.version == base_version,
            WorkOrder.deleted_at.is_(None),
        )
        .values(**values, version=base_version + 1, updated_at=now)
    )

    if getattr(result, "rowcount", 0) == 0:
        db.rollback()
        current = db.scalar(
            select(WorkOrder)
            .where(WorkOrder.id == work_order.id)
            .execution_options(populate_existing=True)
        )
        if current is None or current.deleted_at is not None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Work order not found",
            )
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail={
                "message": "Version conflict",
                "current": WorkOrderRead.model_validate(current).model_dump(mode="json"),
            },
        )

    db.flush()
    updated = get_work_order_or_404(db, work_order.id)

    if idempotency_key is not None:
        db.add(
            ProcessedOperation(
                op_id=idempotency_key,
                work_order_id=work_order.id,
                response_json=WorkOrderRead.model_validate(updated).model_dump(mode="json"),
            )
        )

    db.commit()
    return updated


def soft_delete_work_order(db: Session, work_order: WorkOrder) -> None:
    now = datetime.now(UTC)
    db.execute(
        update(WorkOrder)
        .where(WorkOrder.id == work_order.id, WorkOrder.deleted_at.is_(None))
        .values(
            deleted_at=now,
            updated_at=now,
            version=WorkOrder.version + 1,
        )
    )
    db.commit()
