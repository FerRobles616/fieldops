import time

from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.user import User
from app.models.work_order import WorkOrder
from tests.factories import create_work_order
from tests.helpers import auth_headers


def test_sync_returns_created_updated_and_deleted_orders(
    client: TestClient,
    admin: User,
    technician: User,
    work_order: WorkOrder,
) -> None:
    headers = auth_headers(client, "admin@example.com", "secret123")

    first = client.get(
        "/sync",
        params={"since": "1970-01-01T00:00:00Z"},
        headers=headers,
    )
    assert first.status_code == 200
    first_body = first.json()
    assert any(item["id"] == str(work_order.id) for item in first_body["items"])
    since = first_body["next_since"]
    assert since.endswith("Z")

    time.sleep(0.01)
    update = client.patch(
        f"/work-orders/{work_order.id}",
        headers=headers,
        json={"base_version": work_order.version, "status": "in_progress"},
    )
    assert update.status_code == 200

    second = client.get(
        "/sync",
        params={"since": since},
        headers=headers,
    )
    assert second.status_code == 200
    second_body = second.json()
    updated_item = next(item for item in second_body["items"] if item["id"] == str(work_order.id))
    assert updated_item["status"] == "in_progress"
    assert updated_item["deleted_at"] is None
    since = second_body["next_since"]

    time.sleep(0.01)
    delete = client.delete(
        f"/work-orders/{work_order.id}",
        headers=headers,
    )
    assert delete.status_code == 204

    third = client.get(
        "/sync",
        params={"since": since},
        headers=headers,
    )
    assert third.status_code == 200
    deleted_item = next(item for item in third.json()["items"] if item["id"] == str(work_order.id))
    assert deleted_item["deleted_at"] is not None


def test_sync_filters_by_technician_assignment(
    client: TestClient,
    db_session: Session,
    admin: User,
    technician: User,
    second_technician: User,
    customer: Customer,
) -> None:
    own_order = create_work_order(
        db_session,
        customer=customer,
        assigned_to=technician,
        code="WO-SYNC-001",
    )
    other_order = create_work_order(
        db_session,
        customer=customer,
        assigned_to=second_technician,
        code="WO-SYNC-002",
    )

    technician_response = client.get(
        "/sync",
        params={"since": "1970-01-01T00:00:00Z"},
        headers=auth_headers(client, "tech@example.com", "secret123"),
    )
    assert technician_response.status_code == 200
    technician_ids = {item["id"] for item in technician_response.json()["items"]}
    assert str(own_order.id) in technician_ids
    assert str(other_order.id) not in technician_ids

    admin_response = client.get(
        "/sync",
        params={"since": "1970-01-01T00:00:00Z"},
        headers=auth_headers(client, "admin@example.com", "secret123"),
    )
    admin_ids = {item["id"] for item in admin_response.json()["items"]}
    assert {str(own_order.id), str(other_order.id)} <= admin_ids


def test_sync_requires_authentication(client: TestClient) -> None:
    response = client.get("/sync")

    assert response.status_code == 401
