from datetime import datetime

from sqlalchemy.orm import Session

from app.core.security import hash_password
from app.models.customer import Customer
from app.models.user import User, UserRole
from app.models.work_order import WorkOrder, WorkOrderPriority, WorkOrderStatus


def create_user(
    db: Session,
    *,
    email: str,
    password: str = "secret123",
    name: str = "User",
    role: UserRole = UserRole.TECHNICIAN,
) -> User:
    user = User(
        email=email,
        password_hash=hash_password(password),
        name=name,
        role=role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


def create_customer(
    db: Session,
    *,
    name: str = "Acme",
    address: str = "1 Main St",
    phone: str = "555-0100",
) -> Customer:
    customer = Customer(name=name, address=address, phone=phone)
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return customer


def create_work_order(
    db: Session,
    *,
    customer: Customer,
    assigned_to: User | None = None,
    code: str = "WO-TEST-001",
    title: str = "Fix HVAC",
    description: str = "Check the unit.",
    status: WorkOrderStatus = WorkOrderStatus.PENDING,
    priority: WorkOrderPriority = WorkOrderPriority.MEDIUM,
    scheduled_at: datetime | None = None,
    version: int = 1,
) -> WorkOrder:
    order = WorkOrder(
        code=code,
        customer_id=customer.id,
        assigned_to_id=assigned_to.id if assigned_to is not None else None,
        title=title,
        description=description,
        status=status,
        priority=priority,
        scheduled_at=scheduled_at,
        version=version,
    )
    db.add(order)
    db.commit()
    db.refresh(order)
    return order
