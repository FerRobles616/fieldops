import uuid
from typing import Annotated

from fastapi import APIRouter, Header, HTTPException, Query, Response, status

from app.api.deps import AdminUser, CurrentUser, DbSession
from app.models.processed_operation import ProcessedOperation
from app.models.user import UserRole
from app.models.work_order import WorkOrder, WorkOrderPriority, WorkOrderStatus
from app.schemas.work_order import (
    WorkOrderCreate,
    WorkOrderPage,
    WorkOrderRead,
    WorkOrderUpdate,
)
from app.services.work_orders import (
    apply_work_order_update,
    ensure_can_view,
    get_customer_or_404,
    get_technician_or_404,
    get_work_order_or_404,
    list_work_orders,
    soft_delete_work_order,
)

router = APIRouter(prefix="/work-orders", tags=["work orders"])


@router.get("", response_model=WorkOrderPage)
def list_orders(
    db: DbSession,
    current_user: CurrentUser,
    status_filter: Annotated[
        WorkOrderStatus | None,
        Query(alias="status"),
    ] = None,
    priority_filter: Annotated[
        WorkOrderPriority | None,
        Query(alias="priority"),
    ] = None,
    q: Annotated[str | None, Query(max_length=100)] = None,
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> WorkOrderPage:
    items, total = list_work_orders(
        db,
        current_user,
        status_filter=status_filter,
        priority_filter=priority_filter,
        query=q,
        limit=limit,
        offset=offset,
    )
    return WorkOrderPage(
        items=[WorkOrderRead.model_validate(item) for item in items],
        total=total,
        limit=limit,
        offset=offset,
    )


@router.post("", response_model=WorkOrderRead, status_code=status.HTTP_201_CREATED)
def create_order(
    payload: WorkOrderCreate,
    db: DbSession,
    _current_user: AdminUser,
) -> WorkOrderRead:
    customer = get_customer_or_404(db, payload.customer_id)
    assigned_to_id = None
    if payload.assigned_to is not None:
        assigned_to_id = get_technician_or_404(db, payload.assigned_to).id

    work_order = WorkOrder(
        customer_id=customer.id,
        assigned_to_id=assigned_to_id,
        title=payload.title,
        description=payload.description,
        status=payload.status,
        priority=payload.priority,
        scheduled_at=payload.scheduled_at,
    )
    db.add(work_order)
    db.commit()

    created = get_work_order_or_404(db, work_order.id)
    return WorkOrderRead.model_validate(created)


@router.get("/{work_order_id}", response_model=WorkOrderRead)
def get_order(
    work_order_id: uuid.UUID,
    db: DbSession,
    current_user: CurrentUser,
) -> WorkOrderRead:
    work_order = get_work_order_or_404(db, work_order_id)
    ensure_can_view(work_order, current_user)
    return WorkOrderRead.model_validate(work_order)


@router.patch("/{work_order_id}", response_model=WorkOrderRead)
def update_order(
    work_order_id: uuid.UUID,
    payload: WorkOrderUpdate,
    db: DbSession,
    current_user: CurrentUser,
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
    ensure_can_view(work_order, current_user)

    updates = payload.model_dump(exclude_unset=True, exclude={"base_version"})
    if not updates:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
            detail="No fields to update",
        )

    if current_user.role == UserRole.TECHNICIAN and set(updates) - {"status"}:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Technicians can only update the status",
        )

    if "assigned_to" in updates:
        assigned_to = updates.pop("assigned_to")
        if assigned_to is None:
            updates["assigned_to_id"] = None
        elif isinstance(assigned_to, uuid.UUID):
            updates["assigned_to_id"] = get_technician_or_404(
                db,
                assigned_to,
            ).id
        else:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_CONTENT,
                detail="Invalid technician id",
            )

    updated = apply_work_order_update(
        db,
        work_order,
        updates,
        payload.base_version,
        idempotency_key=idempotency_key,
    )
    return WorkOrderRead.model_validate(updated)


@router.delete(
    "/{work_order_id}",
    status_code=status.HTTP_204_NO_CONTENT,
)
def delete_order(
    work_order_id: uuid.UUID,
    db: DbSession,
    _current_user: AdminUser,
) -> Response:
    work_order = get_work_order_or_404(db, work_order_id)
    soft_delete_work_order(db, work_order)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
