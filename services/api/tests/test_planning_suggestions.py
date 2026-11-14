from decimal import Decimal

from app.features.planning.suggestions import suggest_allowances


def _by_category(items):
    return {item.category: item for item in items}


def test_overnight_trip_suggests_lodging_and_leaves_money_unallocated() -> None:
    items = _by_category(suggest_allowances(Decimal("10000.00"), 1))

    assert items["transportation"].amount == Decimal("2000.00")
    assert items["food"].amount == Decimal("2500.00")
    assert items["accommodation"].amount == Decimal("3000.00")
    assert items["other"].amount == Decimal("500.00")
    assert sum(item.amount for item in items.values()) < Decimal("10000.00")
    assert all(item.source == "system_estimate" for item in items.values())


def test_day_trip_omits_lodging() -> None:
    items = _by_category(suggest_allowances(Decimal("5000.00"), 0))

    assert "accommodation" not in items
    assert items["transportation"].amount == Decimal("1250.00")
    assert items["food"].amount == Decimal("1500.00")


def test_amounts_round_to_the_nearest_fifty_pesos() -> None:
    items = _by_category(suggest_allowances(Decimal("1234.00"), 1))

    assert all(item.amount % Decimal("50") == 0 for item in items.values())


def test_no_budget_means_no_suggestions() -> None:
    assert suggest_allowances(None, 1) == []
    assert suggest_allowances(Decimal("0"), 1) == []
