import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.models.work_order import WorkOrderPriority, WorkOrderStatus
from app.schemas.auth import UserRead
from app.schemas.customer import CustomerRead


class WorkOrderCreate(BaseModel):
    customer_id: uuid.UUID
    assigned_to: uuid.UUID | None = None
    title: str = Field(min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=5000)
    status: WorkOrderStatus = WorkOrderStatus.PENDING
    priority: WorkOrderPriority = WorkOrderPriority.MEDIUM
    scheduled_at: datetime | None = None


class WorkOrderUpdate(BaseModel):
    base_version: int = Field(ge=1)
    title: str | None = Field(default=None, min_length=1, max_length=160)
    description: str | None = Field(default=None, max_length=5000)
    status: WorkOrderStatus | None = None
    priority: WorkOrderPriority | None = None
    scheduled_at: datetime | None = None
    assigned_to: uuid.UUID | None = None


class WorkOrderAssign(BaseModel):
    assigned_to: uuid.UUID
    base_version: int = Field(ge=1)


class WorkOrderRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    code: str
    customer: CustomerRead
    assigned_to: UserRead | None
    title: str
    description: str | None
    status: WorkOrderStatus
    priority: WorkOrderPriority
    scheduled_at: datetime | None
    version: int
    created_at: datetime
    updated_at: datetime


class WorkOrderSyncRead(WorkOrderRead):
    deleted_at: datetime | None


class WorkOrderSyncPage(BaseModel):
    items: list[WorkOrderSyncRead]
    next_since: str


class WorkOrderPage(BaseModel):
    items: list[WorkOrderRead]
    total: int
    limit: int
    offset: int
