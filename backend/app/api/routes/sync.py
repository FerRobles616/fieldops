from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Query
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.models.user import UserRole
from app.models.work_order import WorkOrder
from app.schemas.work_order import WorkOrderSyncPage, WorkOrderSyncRead

router = APIRouter(tags=["sync"])

_EPOCH = datetime(1970, 1, 1, tzinfo=UTC)


def _to_utc_iso(value: datetime) -> str:
    if value.tzinfo is None:
        value = value.replace(tzinfo=UTC)
    return value.astimezone(UTC).isoformat().replace("+00:00", "Z")


@router.get("/sync", response_model=WorkOrderSyncPage)
def sync_work_orders(
    db: DbSession,
    current_user: CurrentUser,
    since: Annotated[datetime | None, Query()] = None,
    limit: Annotated[int, Query(ge=1, le=500)] = 200,
) -> WorkOrderSyncPage:
    since_value = since or _EPOCH
    if since_value.tzinfo is None:
        since_value = since_value.replace(tzinfo=UTC)
    else:
        since_value = since_value.astimezone(UTC)

    conditions = [WorkOrder.updated_at > since_value]
    if current_user.role == UserRole.TECHNICIAN:
        conditions.append(WorkOrder.assigned_to_id == current_user.id)

    items = list(
        db.scalars(
            select(WorkOrder)
            .where(*conditions)
            .order_by(WorkOrder.updated_at.asc(), WorkOrder.id.asc())
            .limit(limit)
        ).all()
    )
    next_since = max((item.updated_at for item in items), default=since_value)

    return WorkOrderSyncPage(
        items=[WorkOrderSyncRead.model_validate(item) for item in items],
        next_since=_to_utc_iso(next_since),
    )
