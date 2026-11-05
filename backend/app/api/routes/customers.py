from fastapi import APIRouter, status
from sqlalchemy import select

from app.api.deps import AdminUser, DbSession
from app.models.customer import Customer
from app.schemas.customer import CustomerCreate, CustomerRead

router = APIRouter(prefix="/customers", tags=["customers"])


@router.post("", response_model=CustomerRead, status_code=status.HTTP_201_CREATED)
def create_customer(
    payload: CustomerCreate,
    db: DbSession,
    _current_user: AdminUser,
) -> CustomerRead:
    customer = Customer(
        name=payload.name,
        address=payload.address,
        phone=payload.phone,
    )
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return CustomerRead.model_validate(customer)


@router.get("", response_model=list[CustomerRead])
def list_customers(
    db: DbSession,
    _current_user: AdminUser,
) -> list[CustomerRead]:
    customers = db.scalars(select(Customer).order_by(Customer.name)).all()
    return [CustomerRead.model_validate(customer) for customer in customers]
