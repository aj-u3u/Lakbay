"""Reproduces the trip-review screen the traveler hit: confirmed amounts that add up to
more than the whole-trip budget. The app blocks "Generate" in that case and shows the
total and the overage, so the backend numbers behind that message must be right."""

from decimal import Decimal

from tests.test_planning_preview import (
    create_destination,
    preview_request,
    register,
)


def _preview(client, destination_id: int, **state) -> dict:
    admin_free_user = register(client)
    response = client.post(
        "/api/v1/planning/preview",
        headers=admin_free_user,
        json=preview_request(
            destination_id,
            total_budget="10000.00",
            reserve_amount="0.00",
            day_count=2,
            night_count=1,
            selected_transport_option_ids=["mode:personal_vehicle"],
            **state,
        ),
    )
    assert response.status_code == 200, response.text
    return response.json()["budget"]


def _allowances(destination_id: int, *, transport: str) -> list[dict]:
    return [
        {"category": "destination", "destination_id": destination_id, "amount": "1000.00"},
        {"category": "food", "amount": "1000.00"},
        {"category": "accommodation", "amount": "1000.00"},
        {"category": "transportation", "amount": transport},
    ]


def test_amounts_above_the_budget_report_the_total_and_the_overage(client) -> None:
    # The screenshot: transport 10,000 + destination 1,000 + food 1,000 + lodging 1,000
    # against a 10,000 whole-trip budget = 13,000, which is 3,000 over.
    destination = create_destination(client, register(client, admin=True))
    budget = _preview(
        client,
        destination["destination_id"],
        cost_allowances=_allowances(destination["destination_id"], transport="10000.00"),
    )

    assert budget["completeness"] == "complete"
    assert budget["fit"] == "over_budget"
    assert Decimal(budget["total_estimate"]) == Decimal("13000.00")
    assert Decimal(budget["over_budget_amount"]) == Decimal("3000.00")


def test_realistic_amounts_fit_the_same_budget(client) -> None:
    destination = create_destination(client, register(client, admin=True))
    budget = _preview(
        client,
        destination["destination_id"],
        cost_allowances=_allowances(destination["destination_id"], transport="1500.00"),
    )

    assert budget["completeness"] == "complete"
    assert budget["fit"] == "fits_estimate"
    assert Decimal(budget["total_estimate"]) == Decimal("4500.00")
    assert not budget["over_budget_amount"] or Decimal(budget["over_budget_amount"]) == 0
