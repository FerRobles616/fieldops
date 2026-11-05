from fastapi.testclient import TestClient
from sqlalchemy.orm import Session

from app.models.customer import Customer
from app.models.user import User
from app.models.work_order import WorkOrder, WorkOrderPriority, WorkOrderStatus
from tests.factories import create_work_order
from tests.helpers import auth_headers


def test_admin_can_create_work_order(
    client: TestClient,
    admin: User,
    technician: User,
    customer: Customer,
) -> None:
    headers = auth_headers(client, "admin@example.com", "secret123")

    response = client.post(
        "/work-orders",
        headers=headers,
        json={
            "customer_id": str(customer.id),
            "assigned_to": str(technician.id),
            "title": "Install new panel",
            "description": "Install and test the panel.",
            "priority": "high",
            "scheduled_at": "2026-11-10T09:00:00Z",
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["code"].startswith("WO-")
    assert body["title"] == "Install new panel"
    assert body["status"] == "pending"
    assert body["priority"] == "high"
    assert body["version"] == 1
    assert body["customer"]["id"] == str(customer.id)
    assert body["assigned_to"]["email"] == "tech@example.com"


def test_technician_cannot_create_work_order(
    client: TestClient,
    technician: User,
    customer: Customer,
) -> None:
    headers = auth_headers(client, "tech@example.com", "secret123")

    response = client.post(
        "/work-orders",
        headers=headers,
        json={"customer_id": str(customer.id), "title": "Nope"},
    )

    assert response.status_code == 403


def test_admin_sees_all_orders_and_technician_only_assigned(
    client: TestClient,
    db_session: Session,
    admin: User,
    technician: User,
    second_technician: User,
    customer: Customer,
) -> None:
    assigned = create_work_order(
        db_session,
        customer=customer,
        assigned_to=technician,
        code="WO-TEST-100",
        title="Assigned order",
    )
    create_work_order(
        db_session,
        customer=customer,
        assigned_to=second_technician,
        code="WO-TEST-101",
        title="Other order",
        status=WorkOrderStatus.DONE,
    )

    admin_response = client.get(
        "/work-orders",
        headers=auth_headers(client, "admin@example.com", "secret123"),
    )
    assert admin_response.status_code == 200
    assert admin_response.json()["total"] == 2

    technician_response = client.get(
        "/work-orders",
        headers=auth_headers(client, "tech@example.com", "secret123"),
    )
    assert technician_response.status_code == 200
    body = technician_response.json()
    assert body["total"] == 1
    assert body["items"][0]["id"] == str(assigned.id)


def test_filters_by_status_priority_and_query(
    client: TestClient,
    db_session: Session,
    admin: User,
    technician: User,
    customer: Customer,
) -> None:
    create_work_order(
        db_session,
        customer=customer,
        assigned_to=technician,
        code="WO-TEST-201",
        title="HVAC service",
        status=WorkOrderStatus.DONE,
        priority=WorkOrderPriority.URGENT,
    )
    create_work_order(
        db_session,
        customer=customer,
        assigned_to=technician,
        code="WO-TEST-202",
        title="Electrical repair",
        status=WorkOrderStatus.PENDING,
        priority=WorkOrderPriority.LOW,
    )

    headers = auth_headers(client, "admin@example.com", "secret123")

    done = client.get("/work-orders?status=done", headers=headers)
    assert done.status_code == 200
    assert done.json()["total"] == 1
    assert done.json()["items"][0]["code"] == "WO-TEST-201"

    urgent = client.get("/work-orders?priority=urgent", headers=headers)
    assert urgent.status_code == 200
    assert urgent.json()["total"] == 1

    search = client.get("/work-orders?q=hvac", headers=headers)
    assert search.status_code == 200
    assert search.json()["total"] == 1
    assert search.json()["items"][0]["code"] == "WO-TEST-201"


def test_pagination(
    client: TestClient,
    db_session: Session,
    admin: User,
    technician: User,
    customer: Customer,
) -> None:
    for index in range(3):
        create_work_order(
            db_session,
            customer=customer,
            assigned_to=technician,
            code=f"WO-TEST-30{index}",
            title=f"Order {index}",
        )

    headers = auth_headers(client, "admin@example.com", "secret123")

    first_page = client.get("/work-orders?limit=2&offset=0", headers=headers)
    assert first_page.status_code == 200
    assert len(first_page.json()["items"]) == 2
    assert first_page.json()["total"] == 3

    second_page = client.get("/work-orders?limit=2&offset=2", headers=headers)
    assert second_page.status_code == 200
    assert len(second_page.json()["items"]) == 1
    assert second_page.json()["total"] == 3


def test_technician_cannot_view_unassigned_order(
    client: TestClient,
    db_session: Session,
    admin: User,
    technician: User,
    second_technician: User,
    customer: Customer,
) -> None:
    order = create_work_order(
        db_session,
        customer=customer,
        assigned_to=second_technician,
        code="WO-TEST-400",
    )

    technician_response = client.get(
        f"/work-orders/{order.id}",
        headers=auth_headers(client, "tech@example.com", "secret123"),
    )
    assert technician_response.status_code == 404

    admin_response = client.get(
        f"/work-orders/{order.id}",
        headers=auth_headers(client, "admin@example.com", "secret123"),
    )
    assert admin_response.status_code == 200


def test_technician_can_update_status(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
) -> None:
    response = client.patch(
        f"/work-orders/{work_order.id}",
        headers=auth_headers(client, "tech@example.com", "secret123"),
        json={"base_version": work_order.version, "status": "in_progress"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "in_progress"
    assert body["version"] == 2


def test_technician_cannot_update_title(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
) -> None:
    response = client.patch(
        f"/work-orders/{work_order.id}",
        headers=auth_headers(client, "tech@example.com", "secret123"),
        json={"base_version": work_order.version, "title": "Changed"},
    )

    assert response.status_code == 403


def test_stale_version_returns_conflict(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
) -> None:
    response = client.patch(
        f"/work-orders/{work_order.id}",
        headers=auth_headers(client, "tech@example.com", "secret123"),
        json={"base_version": 99, "status": "done"},
    )

    assert response.status_code == 409
    detail = response.json()["detail"]
    assert detail["message"] == "Version conflict"
    assert detail["current"]["version"] == 1


def test_admin_can_update_title_and_priority(
    client: TestClient,
    admin: User,
    work_order: WorkOrder,
) -> None:
    response = client.patch(
        f"/work-orders/{work_order.id}",
        headers=auth_headers(client, "admin@example.com", "secret123"),
        json={
            "base_version": work_order.version,
            "title": "Updated title",
            "priority": "urgent",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["title"] == "Updated title"
    assert body["priority"] == "urgent"
    assert body["version"] == 2


def test_update_without_fields_returns_422(
    client: TestClient,
    admin: User,
    work_order: WorkOrder,
) -> None:
    response = client.patch(
        f"/work-orders/{work_order.id}",
        headers=auth_headers(client, "admin@example.com", "secret123"),
        json={"base_version": work_order.version},
    )

    assert response.status_code == 422


def test_admin_can_assign_work_order(
    client: TestClient,
    admin: User,
    technician: User,
    second_technician: User,
    work_order: WorkOrder,
) -> None:
    response = client.patch(
        f"/admin/work-orders/{work_order.id}/assign",
        headers=auth_headers(client, "admin@example.com", "secret123"),
        json={
            "assigned_to": str(second_technician.id),
            "base_version": work_order.version,
        },
    )

    assert response.status_code == 200
    assert response.json()["assigned_to"]["email"] == "tech2@example.com"

    second_technician_response = client.get(
        f"/work-orders/{work_order.id}",
        headers=auth_headers(client, "tech2@example.com", "secret123"),
    )
    assert second_technician_response.status_code == 200


def test_assign_to_non_technician_returns_404(
    client: TestClient,
    admin: User,
    work_order: WorkOrder,
) -> None:
    response = client.patch(
        f"/admin/work-orders/{work_order.id}/assign",
        headers=auth_headers(client, "admin@example.com", "secret123"),
        json={
            "assigned_to": str(admin.id),
            "base_version": work_order.version,
        },
    )

    assert response.status_code == 404


def test_admin_can_soft_delete_work_order(
    client: TestClient,
    admin: User,
    work_order: WorkOrder,
) -> None:
    headers = auth_headers(client, "admin@example.com", "secret123")

    delete_response = client.delete(
        f"/work-orders/{work_order.id}",
        headers=headers,
    )
    assert delete_response.status_code == 204

    get_response = client.get(f"/work-orders/{work_order.id}", headers=headers)
    assert get_response.status_code == 404

    list_response = client.get("/work-orders", headers=headers)
    assert list_response.status_code == 200
    assert list_response.json()["total"] == 0


def test_technician_cannot_delete_work_order(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
) -> None:
    response = client.delete(
        f"/work-orders/{work_order.id}",
        headers=auth_headers(client, "tech@example.com", "secret123"),
    )

    assert response.status_code == 403
