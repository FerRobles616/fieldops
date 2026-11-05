from datetime import UTC, datetime, timedelta

from sqlalchemy import select

from app.core.security import hash_password
from app.db.session import SessionLocal
from app.models.customer import Customer
from app.models.user import User, UserRole
from app.models.work_order import WorkOrder, WorkOrderPriority, WorkOrderStatus

DEMO_USERS = (
    ("admin@fieldops.dev", "admin1234", "Admin Demo", UserRole.ADMIN),
    ("tech@fieldops.dev", "tech1234", "Tech Demo", UserRole.TECHNICIAN),
)

DEMO_CUSTOMERS = (
    ("Northwind Manufacturing", "1200 Industrial Ave", "+1 555 0101"),
    ("Lakeside Hotel", "45 Harbor Road", "+1 555 0102"),
    ("Green Valley Clinic", "8 Wellness Street", "+1 555 0103"),
)

DEMO_WORK_ORDERS = (
    (
        "WO-DEMO-001",
        0,
        "Quarterly HVAC inspection",
        "Check filters, belts, and refrigerant levels.",
        WorkOrderStatus.PENDING,
        WorkOrderPriority.HIGH,
        1,
    ),
    (
        "WO-DEMO-002",
        1,
        "Elevator emergency call",
        "Inspect the elevator controller and test the emergency phone.",
        WorkOrderStatus.IN_PROGRESS,
        WorkOrderPriority.URGENT,
        0,
    ),
    (
        "WO-DEMO-003",
        2,
        "Waiting room outlet repair",
        "Replace two damaged outlets in the waiting room.",
        WorkOrderStatus.PENDING,
        WorkOrderPriority.MEDIUM,
        3,
    ),
    (
        "WO-DEMO-004",
        0,
        "Loading dock lighting",
        "Replace three failed LED fixtures.",
        WorkOrderStatus.DONE,
        WorkOrderPriority.LOW,
        -2,
    ),
)


def seed() -> None:
    with SessionLocal() as db:
        for email, password, name, role in DEMO_USERS:
            existing = db.scalar(select(User).where(User.email == email))
            if existing is None:
                db.add(
                    User(
                        email=email,
                        password_hash=hash_password(password),
                        name=name,
                        role=role,
                    )
                )
        db.flush()

        technician = db.scalar(select(User).where(User.email == "tech@fieldops.dev"))

        customers: list[Customer] = []
        for name, address, phone in DEMO_CUSTOMERS:
            customer = db.scalar(select(Customer).where(Customer.name == name))
            if customer is None:
                customer = Customer(name=name, address=address, phone=phone)
                db.add(customer)
                db.flush()
            customers.append(customer)

        if technician is not None:
            now = datetime.now(UTC)
            for (
                code,
                customer_index,
                title,
                description,
                status_value,
                priority,
                scheduled_days,
            ) in DEMO_WORK_ORDERS:
                existing_order = db.scalar(select(WorkOrder).where(WorkOrder.code == code))
                if existing_order is None:
                    db.add(
                        WorkOrder(
                            code=code,
                            customer_id=customers[customer_index].id,
                            assigned_to_id=technician.id,
                            title=title,
                            description=description,
                            status=status_value,
                            priority=priority,
                            scheduled_at=now + timedelta(days=scheduled_days),
                        )
                    )

        db.commit()


if __name__ == "__main__":
    seed()
