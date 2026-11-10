from decimal import Decimal

from app.features.destinations.models import Destination
from app.features.planning.feedback import evaluate_preview
from app.features.planning.schemas import PlanningPreviewResponse, PlanningRoutePreview
from app.features.routes.schemas import RouteSummaryResponse
from app.integrations.groq.client import get_groq_client
from tests.test_planning_costs import budgeted_request
from tests.test_planning_preview import create_destination, preview_request, register


def _findings(body: dict) -> dict[str, dict]:
    return {item["code"]: item for item in body["findings"]}


def test_feedback_requires_authentication_and_reuses_stateless_preview(client) -> None:
    assert client.post("/api/v1/planning/feedback", json={}).status_code == 401
    admin = register(client, admin=True)
    destination = create_destination(client, admin, estimated_cost=None)
    traveler = register(client)
    client.app.dependency_overrides[get_groq_client] = lambda: (_ for _ in ()).throw(
        AssertionError("Feedback must not call AI.")
    )
    request = preview_request(destination["destination_id"])

    response = client.post("/api/v1/planning/feedback", headers=traveler, json=request)

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["input_revision"] == 7
    assert body["traveling_with_children"] is None
    assert body["preview"]["input_revision"] == 7
    assert body["preview"]["destinations"][0]["catalog_estimated_cost"] is None
    assert body["status"] == "needs_review"
    assert {"catalog_cost_unknown", "budget_incomplete", "arrival_unverified", "route_not_requested"}.issubset(_findings(body))
    assert _findings(body)["arrival_unverified"]["destination_ids"] == [destination["destination_id"]]
    assert client.get("/api/v1/trips", headers=traveler).json() == []


def test_known_zero_is_not_reported_as_unknown_and_missing_details_are_required(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin, estimated_cost="0.00")
    traveler = register(client)
    request = preview_request(destination["destination_id"])
    request["state"]["day_count"] = None

    response = client.post("/api/v1/planning/feedback", headers=traveler, json=request)

    assert response.status_code == 200
    body = response.json()
    assert body["preview"]["destinations"][0]["catalog_estimated_cost"] == "0.00"
    assert body["status"] == "needs_details"
    assert "trip_details_missing" in _findings(body)
    assert "catalog_cost_unknown" not in _findings(body)


def test_unpinned_start_is_required_only_when_a_route_is_requested(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    traveler = register(client)
    request = preview_request(
        destination["destination_id"], origin={"label": "Davao City", "lat": None, "lng": None},
    )

    without_route = client.post("/api/v1/planning/feedback", headers=traveler, json=request)
    request["state"]["route_preferences"] = {"optimize_order": False}
    with_route = client.post("/api/v1/planning/feedback", headers=traveler, json=request)

    assert without_route.status_code == 200, without_route.text
    assert "origin.coordinates" in without_route.json()["preview"]["missing_inputs"]
    assert "trip_details_missing" not in _findings(without_route.json())
    assert without_route.json()["status"] != "needs_details"
    assert with_route.status_code == 200, with_route.text
    assert _findings(with_route.json())["trip_details_missing"]["fields"] == ["origin.coordinates"]
    assert with_route.json()["status"] == "needs_details"


def test_feedback_flags_activity_load_and_child_suitability_without_pricing_children(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(
        client, admin,
        activities="Swimming, Hiking, Photography, Birding, Kayaking",
        is_kid_friendly=False,
    )
    traveler = register(client)
    request = preview_request(destination["destination_id"])
    preview = client.post("/api/v1/planning/preview", headers=traveler, json=request)
    assert preview.status_code == 200
    request["state"]["selected_activity_option_ids"] = [
        item["option_id"] for item in preview.json()["activity_options"]
    ]
    request["traveling_with_children"] = True

    response = client.post("/api/v1/planning/feedback", headers=traveler, json=request)

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["traveling_with_children"] is True
    assert "activity_load_high" in _findings(body)
    assert _findings(body)["child_suitability_review"]["destination_ids"] == [destination["destination_id"]]
    assert body["preview"]["state"]["selected_activity_option_ids"] == request["state"]["selected_activity_option_ids"]

    request["traveling_with_children"] = False
    without_children = client.post(
        "/api/v1/planning/feedback", headers=traveler, json=request,
    )
    assert without_children.status_code == 200
    assert "child_suitability_review" not in _findings(without_children.json())


def test_feedback_reports_proven_over_budget_even_when_other_costs_are_missing(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    traveler = register(client)
    request = budgeted_request(
        destination["destination_id"],
        total_budget="1000.00",
        reserve_amount="100.00",
        cost_allowances=[{"category": "food", "amount": "1500.00"}],
    )

    response = client.post("/api/v1/planning/feedback", headers=traveler, json=request)

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["preview"]["budget"]["fit"] == "over_budget"
    assert body["preview"]["budget"]["completeness"] == "partial"
    assert {"over_budget", "budget_incomplete"}.issubset(_findings(body))


def test_feedback_uses_review_heuristics_only_when_route_summary_exists(client) -> None:
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    traveler = register(client)
    request = preview_request(destination["destination_id"])
    response = client.post("/api/v1/planning/preview", headers=traveler, json=request)
    assert response.status_code == 200
    preview = PlanningPreviewResponse.model_validate(response.json())
    route = PlanningRoutePreview(
        status="calculated",
        travel_mode="walking",
        summary=RouteSummaryResponse(
            travel_mode="walking",
            route_provider="test",
            is_estimated=False,
            total_distance_km=Decimal("12.00"),
            total_duration_minutes=300,
            stops=[],
            legs=[],
            arrival_points_verified=True,
        ),
    )
    preview = preview.model_copy(update={"route": route})
    catalog = Destination(
        destination_id=destination["destination_id"],
        name=destination["name"],
        lat=destination["lat"],
        lng=destination["lng"],
        estimated_cost=Decimal("0.00"),
        route_ready=True,
        is_kid_friendly=True,
    )

    feedback = evaluate_preview(preview, [catalog], traveling_with_children=False)

    codes = {item.code for item in feedback.findings}
    assert "travel_time_high" in codes
    assert "walking_distance_high" in codes
    assert "route_estimated" not in codes

    estimated_route = route.model_copy(update={
        "summary": route.summary.model_copy(update={
            "is_estimated": True,
            "arrival_points_verified": False,
        }),
    })
    estimated_preview = preview.model_copy(update={"route": estimated_route})
    estimated = evaluate_preview(
        estimated_preview, [catalog], traveling_with_children=False,
    )
    assert "route_estimated" in {item.code for item in estimated.findings}
