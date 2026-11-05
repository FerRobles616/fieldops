from collections.abc import Generator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db.session import get_db
from app.main import app
from app.models.customer import Customer
from app.models.user import User, UserRole
from app.models.work_order import WorkOrder, WorkOrderPriority
from app.services.storage import LocalStorageService, get_storage_service
from tests.factories import create_customer, create_user, create_work_order


@pytest.fixture()
def db_session() -> Generator[Session, None, None]:
    engine = create_engine(
        "sqlite://",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=engine)

    testing_session = sessionmaker(
        bind=engine,
        autoflush=False,
        autocommit=False,
        expire_on_commit=False,
    )

    with testing_session() as session:
        yield session

    Base.metadata.drop_all(bind=engine)
    engine.dispose()


@pytest.fixture()
def storage(tmp_path: Path) -> LocalStorageService:
    return LocalStorageService(tmp_path)


@pytest.fixture()
def client(
    db_session: Session,
    storage: LocalStorageService,
) -> Generator[TestClient, None, None]:
    def override_get_db() -> Generator[Session, None, None]:
        yield db_session

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_storage_service] = lambda: storage
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture()
def technician(db_session: Session) -> User:
    return create_user(
        db_session,
        email="tech@example.com",
        name="Tech",
        role=UserRole.TECHNICIAN,
    )


@pytest.fixture()
def second_technician(db_session: Session) -> User:
    return create_user(
        db_session,
        email="tech2@example.com",
        name="Tech Two",
        role=UserRole.TECHNICIAN,
    )


@pytest.fixture()
def admin(db_session: Session) -> User:
    return create_user(
        db_session,
        email="admin@example.com",
        name="Admin",
        role=UserRole.ADMIN,
    )


@pytest.fixture()
def customer(db_session: Session) -> Customer:
    return create_customer(db_session, name="Acme")


@pytest.fixture()
def work_order(
    db_session: Session,
    customer: Customer,
    technician: User,
) -> WorkOrder:
    return create_work_order(
        db_session,
        customer=customer,
        assigned_to=technician,
        code="WO-TEST-001",
        title="Fix HVAC",
        priority=WorkOrderPriority.HIGH,
    )
