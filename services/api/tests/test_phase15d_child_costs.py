"""Explicit age bands price children without inventing catalog discounts."""

from tests.test_planning_costs import (
    baseline_allowances, budgeted_request, request_preview,
)
from tests.test_planning_preview import create_destination, create_transportation, register


def test_destination_age_bands_price_free_half_and_full(client):
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    destination_id = destination["destination_id"]
    allowances = [
        {"category": "food", "amount": "200.00"},
        {"category": "transportation", "amount": "300.00"},
    ]
    request = budgeted_request(
        destination_id, traveler_count=4, adult_count=1,
        child_ages=[4, 10, 16], reserve_amount="0.00",
        cost_allowances=allowances,
        age_pricing_rules=[{
            "category": "destination", "reference_id": f"destination:{destination_id}",
            "adult_unit_amount": "100.00",
            "child_bands": [
                {"min_age": 0, "max_age": 5, "rate": "free"},
                {"min_age": 6, "max_age": 12, "rate": "half"},
                {"min_age": 13, "max_age": 17, "rate": "full"},
            ],
        }],
    )

    budget = request_preview(client, register(client), request)["budget"]

    assert budget["completeness"] == "complete"
    assert budget["category_totals"]["destination"] == "250.00"
    assert budget["total_estimate"] == "750.00"
    destination_lines = [item for item in budget["lines"] if item["category"] == "destination"]
    assert [item["amount"] for item in destination_lines] == ["100.00", "0.00", "50.00", "100.00"]
    assert {item["source"] for item in destination_lines} == {"traveler_age_pricing_rule"}


def test_child_fare_rule_uses_catalog_adult_rate_and_missing_rule_stays_partial(client):
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    destination_id = destination["destination_id"]
    transport = create_transportation(
        client, admin, destination_id, route_to=destination["name"],
        charging_unit="per_person",
    )
    option_id = f"transportation:{transport['transportation_id']}"
    request = budgeted_request(
        destination_id, traveler_count=4, adult_count=2, child_ages=[5, 10],
        return_to_origin=False, reserve_amount="0.00",
        selected_transport_option_ids=[option_id],
        cost_allowances=baseline_allowances(destination_id, transport=False),
        transport_pricing=[{
            "option_id": option_id, "price_basis": "per_person", "charge_count": 2,
        }],
    )
    user = register(client)

    incomplete = request_preview(client, user, request)["budget"]
    assert incomplete["completeness"] == "partial"
    assert incomplete["total_estimate"] is None
    assert incomplete["category_totals"]["transportation"] == "480.00"
    assert any(item["code"] == "child_price_rule_missing" for item in incomplete["missing_costs"])

    request["state"]["age_pricing_rules"] = [{
        "category": "transportation", "reference_id": option_id,
        "child_bands": [
            {"min_age": 0, "max_age": 5, "rate": "free"},
            {"min_age": 6, "max_age": 12, "rate": "half"},
        ],
    }]
    priced = request_preview(client, user, request)["budget"]
    assert priced["completeness"] == "complete"
    assert priced["category_totals"]["transportation"] == "600.00"
    assert priced["total_estimate"] == "900.00"
    fare_lines = [item for item in priced["lines"] if item["category"] == "transportation"]
    assert [item["amount"] for item in fare_lines] == ["480.00", "0.00", "120.00"]
    assert fare_lines[0]["source"] == "catalog_price_with_verified_basis"
    assert {item["source"] for item in fare_lines[1:]} == {"traveler_age_pricing_rule"}


def test_child_age_gaps_and_overlapping_rules_are_rejected_or_partial(client):
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    destination_id = destination["destination_id"]
    user = register(client)
    request = budgeted_request(
        destination_id, traveler_count=2, adult_count=1, child_ages=[8],
        cost_allowances=baseline_allowances(destination_id, transport=False)[1:],
        age_pricing_rules=[{
            "category": "destination", "reference_id": f"destination:{destination_id}",
            "adult_unit_amount": "100.00",
            "child_bands": [{"min_age": 0, "max_age": 5, "rate": "free"}],
        }],
    )
    partial = request_preview(client, user, request)["budget"]
    assert partial["completeness"] == "partial"
    assert any(item["code"] == "child_price_band_missing" for item in partial["missing_costs"])
    assert partial["category_totals"]["destination"] == "100.00"

    request["state"]["age_pricing_rules"][0]["child_bands"].append(
        {"min_age": 4, "max_age": 10, "rate": "half"}
    )
    overlap = client.post("/api/v1/planning/preview", headers=user, json=request)
    assert overlap.status_code == 422

    request["state"]["age_pricing_rules"][0]["child_bands"].pop()
    request["state"]["adult_count"] = 2
    mismatch = client.post("/api/v1/planning/preview", headers=user, json=request)
    assert mismatch.status_code == 422


def test_selected_activity_uses_explicit_half_rate_with_cent_rounding(client):
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    destination_id = destination["destination_id"]
    user = register(client)
    activity_id = request_preview(
        client, user, budgeted_request(destination_id),
    )["activity_options"][0]["option_id"]
    request = budgeted_request(
        destination_id, traveler_count=2, adult_count=1, child_ages=[9],
        selected_activity_option_ids=[activity_id],
        age_pricing_rules=[{
            "category": "activity", "reference_id": activity_id,
            "adult_unit_amount": "101.01",
            "child_bands": [{"min_age": 9, "max_age": 9, "rate": "half"}],
        }],
    )

    budget = request_preview(client, user, request)["budget"]

    assert budget["completeness"] == "complete"
    assert budget["category_totals"]["activity"] == "151.52"
    activity_lines = [item for item in budget["lines"] if item["category"] == "activity"]
    assert [item["amount"] for item in activity_lines] == ["101.01", "50.51"]
    assert activity_lines[1]["unit_amount"] == "50.51"


def test_age_rule_cannot_overlap_existing_destination_allowance(client):
    admin = register(client, admin=True)
    destination = create_destination(client, admin)
    destination_id = destination["destination_id"]
    request = budgeted_request(
        destination_id, traveler_count=2, adult_count=1, child_ages=[7],
        age_pricing_rules=[{
            "category": "destination", "reference_id": f"destination:{destination_id}",
            "adult_unit_amount": "100.00",
            "child_bands": [{"min_age": 7, "max_age": 7, "rate": "half"}],
        }],
    )

    body = request_preview(client, register(client), request)

    assert any(problem["field"] == "age_pricing_rules" for problem in body["selection_problems"])
    assert body["budget"]["completeness"] == "partial"
    assert body["budget"]["category_totals"]["destination"] == "100.00"
