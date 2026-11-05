from datetime import timedelta

from fastapi.testclient import TestClient

from app.core.security import create_access_token
from app.models.user import User
from tests.helpers import auth_headers


def test_login_returns_token_and_user(client: TestClient, technician: User) -> None:
    response = client.post(
        "/auth/login",
        json={"email": "tech@example.com", "password": "secret123"},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["token_type"] == "bearer"
    assert body["access_token"]
    assert body["expires_in"] > 0
    assert body["user"]["email"] == "tech@example.com"
    assert body["user"]["role"] == "technician"


def test_login_is_case_insensitive(client: TestClient, technician: User) -> None:
    response = client.post(
        "/auth/login",
        json={"email": "TECH@EXAMPLE.COM", "password": "secret123"},
    )

    assert response.status_code == 200


def test_login_rejects_wrong_password(client: TestClient, technician: User) -> None:
    response = client.post(
        "/auth/login",
        json={"email": "tech@example.com", "password": "wrong-password"},
    )

    assert response.status_code == 401
    assert response.json()["detail"] == "Invalid email or password"


def test_login_rejects_unknown_email(client: TestClient) -> None:
    response = client.post(
        "/auth/login",
        json={"email": "nobody@example.com", "password": "secret123"},
    )

    assert response.status_code == 401


def test_me_requires_authentication(client: TestClient) -> None:
    response = client.get("/me")

    assert response.status_code == 401


def test_me_rejects_invalid_token(client: TestClient) -> None:
    response = client.get(
        "/me",
        headers={"Authorization": "Bearer not-a-valid-token"},
    )

    assert response.status_code == 401


def test_me_returns_current_user(client: TestClient, technician: User) -> None:
    headers = auth_headers(client, "tech@example.com", "secret123")

    response = client.get("/me", headers=headers)

    assert response.status_code == 200
    assert response.json()["id"] == str(technician.id)
    assert response.json()["email"] == "tech@example.com"


def test_expired_token_is_rejected(client: TestClient, technician: User) -> None:
    token = create_access_token(
        str(technician.id),
        expires_delta=timedelta(seconds=-1),
    )

    response = client.get(
        "/me",
        headers={"Authorization": f"Bearer {token}"},
    )

    assert response.status_code == 401
