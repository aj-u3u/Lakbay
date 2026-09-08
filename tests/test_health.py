from fastapi.testclient import TestClient

from app.main import create_app


def test_health_endpoint_returns_foundation_status(monkeypatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/db")

    client = TestClient(create_app())
    response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "app_name": "Lakbay API",
        "environment": "local",
        "api_prefix": "/api/v1",
        "timezone": "Asia/Manila",
    }


def test_not_found_uses_standard_error_shape(monkeypatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://user:pass@localhost/db")

    client = TestClient(create_app())
    response = client.get("/api/v1/missing")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "not_found"
