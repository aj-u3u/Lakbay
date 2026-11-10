"""Geo context must preserve route and budget uncertainty in AI prompts."""

from decimal import Decimal
from types import SimpleNamespace

import pytest

from app.core.exceptions import LakbayAPIError
from app.features.ai.schemas import AIItineraryGenerateRequest
from app.features.ai.service import _validate_generation_planning_state
from app.features.geo_analytics.schemas import DestinationGroupsResponse
from app.features.planning.schemas import PlanningState
from app.integrations.groq.prompts import build_geo_analytics_context


@pytest.mark.parametrize(
    ("scope", "travelers", "whole_trip_budget"),
    [
        ("per_person", 3, "9000.15"),
        ("per_person", 1, "3000.05"),
        ("whole_trip", 3, "3000.05"),
    ],
)
def test_generation_budget_matches_canonical_preview(scope, travelers, whole_trip_budget):
    state = PlanningState(
        destination_ids=[7], total_budget=Decimal("3000.05"),
        budget_scope=scope, traveler_count=travelers, day_count=1,
    )
    preview = SimpleNamespace(
        state=state, transport_options=[], selection_problems=[],
        budget=SimpleNamespace(minimum_over_budget_amount=Decimal("0")),
        whole_trip_budget=Decimal(whole_trip_budget),
    )
    data = AIItineraryGenerateRequest(
        destination_ids=[7], total_budget=whole_trip_budget,
        traveler_count=travelers, day_count=1, planning_state=state,
    )
    _validate_generation_planning_state(data, preview)
    assert data.planning_state.total_budget == Decimal("3000.05")
    if scope == "per_person" and travelers > 1:
        with pytest.raises(LakbayAPIError) as error:
            _validate_generation_planning_state(
                data.model_copy(update={"total_budget": state.total_budget}), preview,
            )
        assert error.value.code == "planning_input_mismatch"


def _preview(*, summary=None, missing_costs=()):
    return SimpleNamespace(
        state=SimpleNamespace(destination_ids=[11, 12]),
        route=SimpleNamespace(
            status="calculated" if summary is not None else "needs_review",
            summary=summary,
            travel_mode="driving",
            order_strategy="optimize",
            warnings=["Check the final approach."],
        ),
        budget=SimpleNamespace(
            completeness="partial" if missing_costs else "complete",
            fit="undetermined" if missing_costs else "fits_estimate",
            priced_subtotal=Decimal("200.00"),
            total_estimate=None if missing_costs else Decimal("200.00"),
            remaining_budget=None if missing_costs else Decimal("800.00"),
            missing_costs=[SimpleNamespace(message=message) for message in missing_costs],
        ),
    )


def test_selected_group_uses_existing_route_order_without_inventing_score():
    summary = SimpleNamespace(
        stops=[SimpleNamespace(destination_id=None), SimpleNamespace(destination_id=12),
               SimpleNamespace(destination_id=11)],
        travel_mode="driving",
        total_distance_km=Decimal("14.50"),
        total_duration_minutes=35,
        route_provider="osrm",
        is_estimated=False,
        arrival_points_verified=True,
    )

    context = build_geo_analytics_context(_preview(summary=summary))

    assert context["destination_groups"] == [{
        "destination_ids": [11, 12],
        "route_order": [12, 11],
        "score_status": "not_scored",
    }]
    assert context["route_summary"]["provider"] == "osrm"
    assert context["route_summary"]["duration_minutes"] == 35
    assert context["budget_projection"]["total_estimate"] == "200.00"


def test_missing_route_and_unknown_cost_stay_explicit():
    context = build_geo_analytics_context(_preview(missing_costs=["Destination cost unknown."]))

    assert context["destination_groups"] == []
    assert context["route_summary"] is None
    assert context["budget_projection"]["total_estimate"] is None
    assert "Destination cost unknown." in context["warnings"]
    assert any("No backend route summary" in warning for warning in context["warnings"])


def test_estimated_route_cannot_claim_verified_arrival():
    summary = SimpleNamespace(
        stops=[SimpleNamespace(destination_id=None), SimpleNamespace(destination_id=11),
               SimpleNamespace(destination_id=12)],
        travel_mode="walking",
        total_distance_km=Decimal("3.00"),
        total_duration_minutes=45,
        route_provider="haversine",
        is_estimated=True,
        arrival_points_verified=False,
    )

    context = build_geo_analytics_context(_preview(summary=summary))

    assert context["route_summary"]["is_estimated"] is True
    assert context["route_summary"]["arrival_points_verified"] is False
    assert any("does not confirm usable visitor arrival points" in item for item in context["warnings"])


def test_empty_phase15b_result_does_not_fall_back_to_unscored_group():
    summary = SimpleNamespace(
        stops=[SimpleNamespace(destination_id=None), SimpleNamespace(destination_id=11),
               SimpleNamespace(destination_id=12)],
        travel_mode="walking", total_distance_km=Decimal("3.00"),
        total_duration_minutes=45, route_provider="haversine",
        is_estimated=True, arrival_points_verified=False,
    )
    groups = DestinationGroupsResponse(
        groups=[], candidates_considered=0,
        warnings=["Destinations with unknown costs were excluded from cost-scored groups."],
    )

    context = build_geo_analytics_context(_preview(summary=summary), scored_groups=groups)

    assert context["grouping_status"] == "no_eligible_groups"
    assert context["destination_groups"] == []
    assert any("unknown costs" in item for item in context["warnings"])
