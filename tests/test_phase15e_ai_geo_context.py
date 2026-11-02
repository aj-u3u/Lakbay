"""Geo context must preserve route and budget uncertainty in AI prompts."""

from decimal import Decimal
from types import SimpleNamespace

from app.features.geo_analytics.schemas import DestinationGroupsResponse
from app.integrations.groq.prompts import build_geo_analytics_context


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
