import pytest
from fastapi.testclient import TestClient

from app.core.config import get_settings
from app.core.exceptions import LakbayAPIError
from app.features.routes import dependencies as route_dependencies
from tests.test_phase6_routes import (
    DESTINATION_A,
    DESTINATION_B,
    admin_headers,
    create_destination,
    user_headers,
)


def _set_route_limit(monkeypatch, limit: int) -> None:
    monkeypatch.setenv("ROUTE_REQUESTS_PER_MINUTE", str(limit))
    get_settings.cache_clear()


def _second_user_headers(client: TestClient) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Other Route User",
            "email": "other-route-user@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def _route_request(client: TestClient) -> dict:
    headers = admin_headers(client)
    first = create_destination(client, headers, DESTINATION_A)
    second = create_destination(client, headers, DESTINATION_B)

    # Public transport never calls OSRM, so no provider fake is needed.
    return {
        "destination_ids": [first["destination_id"], second["destination_id"]],
        "travel_mode": "public_transport",
    }


def test_route_preview_is_rate_limited_per_user(client, monkeypatch) -> None:
    _set_route_limit(monkeypatch, 2)
    payload = _route_request(client)
    user = user_headers(client)

    for _ in range(2):
        allowed = client.post("/api/v1/routes/preview", headers=user, json=payload)
        assert allowed.status_code == 200

    blocked = client.post("/api/v1/routes/preview", headers=user, json=payload)

    assert blocked.status_code == 429
    body = blocked.json()["error"]
    assert body["code"] == "route_rate_limited"
    retry_after = int(blocked.headers["Retry-After"])
    assert 1 <= retry_after <= 60
    assert body["details"]["retry_after_seconds"] == retry_after


def test_route_limit_is_shared_by_preview_and_optimize(client, monkeypatch) -> None:
    _set_route_limit(monkeypatch, 2)
    payload = _route_request(client)
    user = user_headers(client)

    assert client.post("/api/v1/routes/preview", headers=user, json=payload).status_code == 200
    assert client.post("/api/v1/routes/optimize", headers=user, json=payload).status_code == 200

    blocked = client.post("/api/v1/routes/optimize", headers=user, json=payload)

    assert blocked.status_code == 429
    assert blocked.json()["error"]["code"] == "route_rate_limited"


def test_route_limit_does_not_affect_other_users(client, monkeypatch) -> None:
    _set_route_limit(monkeypatch, 1)
    payload = _route_request(client)
    user = user_headers(client)
    other = _second_user_headers(client)

    assert client.post("/api/v1/routes/preview", headers=user, json=payload).status_code == 200
    assert client.post("/api/v1/routes/preview", headers=user, json=payload).status_code == 429
    assert client.post("/api/v1/routes/preview", headers=other, json=payload).status_code == 200


def test_unauthenticated_route_request_is_rejected_before_the_limit(client, monkeypatch) -> None:
    _set_route_limit(monkeypatch, 1)
    payload = {"destination_ids": [1], "travel_mode": "driving"}

    for _ in range(3):
        response = client.post("/api/v1/routes/preview", json=payload)
        assert response.status_code == 401
        assert response.json()["error"]["code"] == "not_authenticated"


def test_route_limit_window_expires(monkeypatch) -> None:
    clock = {"now": 100.0}
    monkeypatch.setattr("app.core.provider_usage.monotonic", lambda: clock["now"])
    limiter = route_dependencies.ProviderLimiter()
    rule = {"limit": 1, "code": "route_rate_limited", "message": "Too many route requests."}

    limiter.reserve("routes:user:1", **rule)
    clock["now"] = 159.0
    with pytest.raises(LakbayAPIError) as rejected:
        limiter.reserve("routes:user:1", **rule)
    assert rejected.value.code == "route_rate_limited"

    clock["now"] = 160.0
    limiter.reserve("routes:user:1", **rule)
