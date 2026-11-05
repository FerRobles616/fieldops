import uuid
from io import BytesIO

from fastapi.testclient import TestClient
from PIL import Image

from app.core.config import get_settings
from app.models.user import User
from app.models.work_order import WorkOrder
from tests.helpers import auth_headers


def _png_bytes() -> bytes:
    buffer = BytesIO()
    Image.new("RGB", (32, 32), (20, 120, 110)).save(
        buffer,
        format="PNG",
    )
    return buffer.getvalue()


def _upload_photo(
    client: TestClient,
    work_order: WorkOrder,
    *,
    idempotency_key: str | None = None,
):
    headers = auth_headers(client, "tech@example.com", "secret123")
    if idempotency_key is not None:
        headers["Idempotency-Key"] = idempotency_key
    return client.post(
        f"/work-orders/{work_order.id}/photos",
        headers=headers,
        files={"file": ("photo.png", _png_bytes(), "image/png")},
        data={"caption": "Before the repair"},
    )


def test_technician_can_upload_list_and_download_photo(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
) -> None:
    upload = _upload_photo(client, work_order, idempotency_key=str(uuid.uuid4()))

    assert upload.status_code == 201
    body = upload.json()
    assert body["work_order_id"] == str(work_order.id)
    assert body["content_type"] == "image/png"
    assert body["caption"] == "Before the repair"
    assert body["file_size"] > 0
    assert body["download_url"].endswith("/file")

    listing = client.get(
        f"/work-orders/{work_order.id}/photos",
        headers=auth_headers(client, "tech@example.com", "secret123"),
    )
    assert listing.status_code == 200
    assert len(listing.json()) == 1
    assert listing.json()[0]["id"] == body["id"]

    download = client.get(
        body["download_url"],
        headers=auth_headers(client, "tech@example.com", "secret123"),
    )
    assert download.status_code == 200
    assert download.headers["content-type"].startswith("image/png")
    assert download.content.startswith(b"\x89PNG")


def test_photo_upload_is_idempotent(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
) -> None:
    key = str(uuid.uuid4())

    first = _upload_photo(client, work_order, idempotency_key=key)
    second = _upload_photo(client, work_order, idempotency_key=key)

    assert first.status_code == 201
    assert second.status_code == 201
    assert first.json()["id"] == second.json()["id"]

    listing = client.get(
        f"/work-orders/{work_order.id}/photos",
        headers=auth_headers(client, "tech@example.com", "secret123"),
    )
    assert len(listing.json()) == 1


def test_photo_upload_rejects_unsupported_type(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
) -> None:
    response = client.post(
        f"/work-orders/{work_order.id}/photos",
        headers=auth_headers(client, "tech@example.com", "secret123"),
        files={"file": ("notes.txt", b"hello", "text/plain")},
    )

    assert response.status_code == 415


def test_photo_upload_rejects_oversized_file(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
    monkeypatch,
) -> None:
    settings = get_settings()
    monkeypatch.setattr(settings, "upload_max_bytes", 10)

    response = client.post(
        f"/work-orders/{work_order.id}/photos",
        headers=auth_headers(client, "tech@example.com", "secret123"),
        files={"file": ("photo.png", _png_bytes(), "image/png")},
    )

    assert response.status_code == 413


def test_other_technician_cannot_access_photos(
    client: TestClient,
    second_technician: User,
    work_order: WorkOrder,
) -> None:
    upload = _upload_photo(client, work_order)

    headers = auth_headers(client, "tech2@example.com", "secret123")
    listing = client.get(
        f"/work-orders/{work_order.id}/photos",
        headers=headers,
    )
    download = client.get(upload.json()["download_url"], headers=headers)

    assert listing.status_code == 404
    assert download.status_code == 404


def test_pdf_report_contains_order_and_photo(
    client: TestClient,
    technician: User,
    work_order: WorkOrder,
) -> None:
    upload = _upload_photo(client, work_order)
    assert upload.status_code == 201

    response = client.get(
        f"/work-orders/{work_order.id}/report.pdf",
        headers=auth_headers(client, "tech@example.com", "secret123"),
    )

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF")
    assert len(response.content) > 1000
