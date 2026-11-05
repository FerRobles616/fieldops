import uuid

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.user import User
from app.models.work_order import WorkOrder
from tests.factories import create_work_order
from tests.helpers import auth_headers


def test_patch_with_idempotency_key_is_applied_once(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
) -> None:
    key = str(uuid.uuid4())
    headers = {
        **auth_headers(client, "tech@example.com", "secret123"),
        "Idempotency-Key": key,
    }
    body = {
        "base_version": work_order.version,
        "status": "in_progress",
    }

    first = client.patch(
        f"/work-orders/{work_order.id}",
        headers=headers,
        json=body,
    )
    assert first.status_code == 200
    assert first.json()["version"] == 2

    second = client.patch(
        f"/work-orders/{work_order.id}",
        headers=headers,
        json=body,
    )
    assert second.status_code == 200
    assert second.json()["version"] == 2
    assert second.json()["status"] == "in_progress"

    third = client.patch(
        f"/work-orders/{work_order.id}",
        headers={
            **auth_headers(client, "tech@example.com", "secret123"),
            "Idempotency-Key": str(uuid.uuid4()),
        },
        json=body,
    )
    assert third.status_code == 409


def test_idempotency_key_cannot_be_reused_across_orders(
    client: TestClient,
    db_session: Session,
    technician: User,
    customer: Customer,
) -> None:
    first_order = create_work_order(
        db_session,
        customer=customer,
        assigned_to=technician,
        code="WO-IDEM-001",
    )
    second_order = create_work_order(
        db_session,
        customer=customer,
        assigned_to=technician,
        code="WO-IDEM-002",
    )
    key = str(uuid.uuid4())
    headers = {
        **auth_headers(client, "tech@example.com", "secret123"),
        "Idempotency-Key": key,
    }

    first = client.patch(
        f"/work-orders/{first_order.id}",
        headers=headers,
        json={
            "base_version": first_order.version,
            "status": "in_progress",
        },
    )
    assert first.status_code == 200

    reused = client.patch(
        f"/work-orders/{second_order.id}",
        headers=headers,
        json={
            "base_version": second_order.version,
            "status": "in_progress",
        },
    )
    assert reused.status_code == 409
    assert "different work order" in reused.json()["detail"]
