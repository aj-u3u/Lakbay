import asyncio
from datetime import datetime, timedelta, timezone

from app.db.session import get_db_session
from app.features.ai.models import AIGenerationRun


def _register(client, *, admin: bool = False) -> tuple[dict[str, str], int]:
    payload = {
        "full_name": "Evaluation Admin" if admin else "Evaluation Traveler",
        "email": "evaluation-admin@example.com" if admin else "evaluation-traveler@example.com",
        "password": "password123",
        "confirm_password": "password123",
    }
    path = "/api/v1/auth/register/admin" if admin else "/api/v1/auth/register"
    if admin:
        payload["admin_registration_code"] = "admin-test-code"
    response = client.post(path, json=payload)
    assert response.status_code == 201
    body = response.json()
    return {"Authorization": f"Bearer {body['tokens']['access_token']}"}, body["user"]["user_id"]


def _create_destination(client, admin: dict[str, str], *, name: str, cost):
    response = client.post(
        "/api/v1/destinations",
        headers=admin,
        json={
            "name": name,
            "district": "Davao City",
            "category": "park",
            "lat": 7.0644,
            "lng": 125.6078,
            "estimated_cost": cost,
        },
    )
    assert response.status_code == 201
    return response.json()


def test_evaluation_summary_is_admin_only_and_empty_metrics_are_explicit(client) -> None:
    traveler, _ = _register(client)
    admin, _ = _register(client, admin=True)
    path = "/api/v1/evaluation/summary"
    assert client.get(path).status_code == 401
    assert client.get(path, headers=traveler).status_code == 403
    assert client.get(f"{path}?window_days=0", headers=admin).status_code == 422

    response = client.get(path, headers=admin)
    assert response.status_code == 200
    body = response.json()
    assert body["ai"]["attempts"] == 0
    assert body["ai"]["average_response_time_ms"] is None
    assert body["ai"]["by_model"] == []
    assert body["recommendations"]["preference_submissions"] == 0
    assert body["recommendations"]["average_catalog_rating"] is None
    assert body["catalog"] == {
        "active_destinations": 0,
        "route_ready_destinations": 0,
        "unknown_cost_destinations": 0,
    }


def test_evaluation_summary_counts_catalog_signals_without_claiming_accuracy(client) -> None:
    admin, _ = _register(client, admin=True)
    traveler, _ = _register(client)
    unknown = _create_destination(client, admin, name="Unpriced Park", cost=None)
    free = _create_destination(client, admin, name="Free Park", cost="0.00")

    listing = client.get("/api/v1/destinations")
    assert listing.status_code == 200
    assert {item["name"]: item["estimated_cost"] for item in listing.json()} == {
        "Unpriced Park": None,
        "Free Park": "0.00",
    }
    recommended = client.post(
        "/api/v1/recommendations",
        headers=traveler,
        json={"preferred_categories": ["park"]},
    )
    assert recommended.status_code == 201
    for interaction in (
        {"interaction_type": "view"},
        {"interaction_type": "save"},
        {"interaction_type": "rate", "rating": 4},
    ):
        response = client.post(
            f"/api/v1/destinations/{free['destination_id']}/interactions",
            headers=traveler,
            json=interaction,
        )
        assert response.status_code == 201

    response = client.get("/api/v1/evaluation/summary", headers=admin)
    assert response.status_code == 200
    body = response.json()
    assert body["catalog"] == {
        "active_destinations": 2,
        "route_ready_destinations": 0,
        "unknown_cost_destinations": 1,
    }
    assert body["recommendations"]["preference_submissions"] == 1
    assert body["recommendations"]["catalog_views"] == 1
    assert body["recommendations"]["catalog_saves"] == 1
    assert body["recommendations"]["catalog_ratings"] == 1
    assert body["recommendations"]["average_catalog_rating"] == 4.0
    assert "not linked" in body["recommendations"]["attribution_note"]
    assert unknown["estimated_cost"] is None


def test_evaluation_summary_aggregates_ai_attempts_inside_window(client) -> None:
    admin, user_id = _register(client, admin=True)
    now = datetime.now(timezone.utc)

    async def seed_runs() -> None:
        generator = client.app.dependency_overrides[get_db_session]()
        session = await anext(generator)
        try:
            session.add_all(
                [
                    AIGenerationRun(
                        user_id=user_id,
                        request_purpose="itinerary",
                        model_role="quality",
                        model_id="test-model",
                        prompt_version="v1",
                        status="succeeded",
                        validation_status="valid",
                        response_time_ms=100,
                        total_tokens=20,
                        fallback_used=False,
                        created_at=now,
                    ),
                    AIGenerationRun(
                        user_id=user_id,
                        request_purpose="itinerary",
                        model_role="quality",
                        model_id="test-model",
                        prompt_version="v1",
                        status="failed",
                        validation_status="invalid",
                        response_time_ms=300,
                        fallback_used=True,
                        created_at=now,
                    ),
                    AIGenerationRun(
                        user_id=user_id,
                        request_purpose="itinerary",
                        model_role="quality",
                        model_id="old-model",
                        prompt_version="v1",
                        status="succeeded",
                        validation_status="valid",
                        response_time_ms=900,
                        created_at=now - timedelta(days=40),
                    ),
                ]
            )
            await session.commit()
        finally:
            await generator.aclose()

    asyncio.run(seed_runs())
    response = client.get("/api/v1/evaluation/summary?window_days=30", headers=admin)
    assert response.status_code == 200
    ai = response.json()["ai"]
    assert ai["attempts"] == 2
    assert ai["succeeded"] == 1
    assert ai["failed"] == 1
    assert ai["valid"] == 1
    assert ai["invalid"] == 1
    assert ai["fallback_used"] == 1
    assert ai["average_response_time_ms"] == 200.0
    assert ai["by_model"] == [
        {
            "model_role": "quality",
            "model_id": "test-model",
            "attempts": 2,
            "succeeded": 1,
            "failed": 1,
            "average_response_time_ms": 200.0,
        }
    ]
