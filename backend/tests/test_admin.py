from fastapi.testclient import TestClient

from app.models.user import User
from tests.helpers import auth_headers


def test_admin_ping_requires_authentication(client: TestClient) -> None:
    response = client.get("/admin/ping")

    assert response.status_code == 401


def test_admin_ping_rejects_technician(
    client: TestClient,
    technician: User,
) -> None:
    headers = auth_headers(client, "tech@example.com", "secret123")

    response = client.get("/admin/ping", headers=headers)

    assert response.status_code == 403


def test_admin_ping_allows_admin(client: TestClient, admin: User) -> None:
    headers = auth_headers(client, "admin@example.com", "secret123")

    response = client.get("/admin/ping", headers=headers)

    assert response.status_code == 200
    assert response.json() == {"status": "admin-only"}


def test_admin_can_list_technicians(
    client: TestClient,
    admin: User,
    technician: User,
    second_technician: User,
) -> None:
    response = client.get(
        "/admin/technicians",
        headers=auth_headers(client, "admin@example.com", "secret123"),
    )

    assert response.status_code == 200
    emails = {user["email"] for user in response.json()}
    assert {"tech@example.com", "tech2@example.com"} <= emails


def test_technician_cannot_list_technicians(
    client: TestClient,
    technician: User,
) -> None:
    response = client.get(
        "/admin/technicians",
        headers=auth_headers(client, "tech@example.com", "secret123"),
    )

    assert response.status_code == 403
