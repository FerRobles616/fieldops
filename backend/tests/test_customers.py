from fastapi.testclient import TestClient

from app.models.user import User
from tests.helpers import auth_headers


def test_admin_can_create_and_list_customers(
    client: TestClient,
    admin: User,
) -> None:
    headers = auth_headers(client, "admin@example.com", "secret123")

    create_response = client.post(
        "/customers",
        headers=headers,
        json={
            "name": "New Co",
            "address": "2 Main St",
            "phone": "555-0199",
        },
    )
    assert create_response.status_code == 201
    assert create_response.json()["name"] == "New Co"

    list_response = client.get("/customers", headers=headers)
    assert list_response.status_code == 200
    assert any(item["name"] == "New Co" for item in list_response.json())


def test_technician_cannot_manage_customers(
    client: TestClient,
    technician: User,
) -> None:
    headers = auth_headers(client, "tech@example.com", "secret123")

    create_response = client.post(
        "/customers",
        headers=headers,
        json={"name": "Forbidden"},
    )
    assert create_response.status_code == 403

    list_response = client.get("/customers", headers=headers)
    assert list_response.status_code == 403
