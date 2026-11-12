import itertools
import math

import pytest

from app.features.routes.ordering import (
    EXACT_ORDER_MAX_STOPS,
    _nearest_neighbor,
    exact_order,
    nearest_neighbor_two_opt,
    order_cost,
)


def straight_line_costs(points: list[tuple[float, float]]) -> list[list[float]]:
    return [[math.dist(start, end) for end in points] for start in points]


def brute_force_cost(costs, *, fixed_start: bool, roundtrip: bool) -> float:
    count = len(costs)
    if fixed_start or roundtrip:
        orders = ([0, *rest] for rest in itertools.permutations(range(1, count)))
    else:
        orders = itertools.permutations(range(count))
    return min(order_cost(costs, list(order), roundtrip=roundtrip) for order in orders)


# One-way costs: going 0 -> 3 -> 2 -> 1 -> 0 is cheap, but the listed direction
# 0 -> 1 -> 2 -> 3 is expensive, like one-way roads.
ASYMMETRIC_COSTS = [
    [0, 9, 9, 1],
    [1, 0, 9, 9],
    [9, 1, 0, 9],
    [9, 9, 1, 0],
]

# Grid points where the greedy nearest-stop order from stop 0 doubles back,
# and 2-opt finds the shortest open path.
DOUBLING_BACK_POINTS = [(2, 6), (4, 3), (6, 6), (0, 2), (1, 1)]


def test_order_cost_adds_return_leg_only_for_roundtrip() -> None:
    assert order_cost(ASYMMETRIC_COSTS, [0, 3, 2, 1], roundtrip=False) == 3
    assert order_cost(ASYMMETRIC_COSTS, [0, 3, 2, 1], roundtrip=True) == 4
    assert order_cost(ASYMMETRIC_COSTS, [2], roundtrip=True) == 0


@pytest.mark.parametrize("method", [exact_order, nearest_neighbor_two_opt])
@pytest.mark.parametrize("count", [0, 1])
def test_ordering_handles_empty_and_single_stop(method, count: int) -> None:
    costs = [[0.0] * count for _ in range(count)]

    assert method(costs, fixed_start=False, roundtrip=False) == list(range(count))


@pytest.mark.parametrize("fixed_start", [True, False])
@pytest.mark.parametrize("roundtrip", [True, False])
def test_exact_order_matches_brute_force(fixed_start: bool, roundtrip: bool) -> None:
    points = [(0, 0), (5, 1), (1, 4), (6, 5), (2, 2), (4, 6), (7, 0)]
    costs = straight_line_costs(points)

    order = exact_order(costs, fixed_start=fixed_start, roundtrip=roundtrip)

    assert sorted(order) == list(range(len(points)))
    assert order_cost(costs, order, roundtrip=roundtrip) == pytest.approx(
        brute_force_cost(costs, fixed_start=fixed_start, roundtrip=roundtrip),
    )


@pytest.mark.parametrize("roundtrip", [True, False])
def test_exact_order_follows_one_way_costs(roundtrip: bool) -> None:
    order = exact_order(ASYMMETRIC_COSTS, fixed_start=True, roundtrip=roundtrip)

    assert order == [0, 3, 2, 1]


@pytest.mark.parametrize("method", [exact_order, nearest_neighbor_two_opt])
def test_fixed_start_and_roundtrip_keep_stop_zero_first(method) -> None:
    # Stop 0 sits in the middle of a line of stops, so the shortest free path
    # starts at an end of the line instead.
    costs = straight_line_costs([(1, 0), (0, 0), (2, 0), (3, 0)])

    free = method(costs, fixed_start=False, roundtrip=False)
    fixed = method(costs, fixed_start=True, roundtrip=False)
    loop = method(costs, fixed_start=False, roundtrip=True)

    assert free[0] != 0
    assert fixed[0] == 0
    assert loop[0] == 0


@pytest.mark.parametrize("method", [exact_order, nearest_neighbor_two_opt])
def test_requested_order_is_kept_when_no_order_is_cheaper(method) -> None:
    # Every leg costs the same, so no order beats the one the traveler gave.
    costs = [[0 if start == end else 1 for end in range(5)] for start in range(5)]

    assert method(costs, fixed_start=False, roundtrip=False) == [0, 1, 2, 3, 4]
    assert method(costs, fixed_start=True, roundtrip=True) == [0, 1, 2, 3, 4]


def test_requested_order_is_kept_when_reversal_costs_the_same() -> None:
    # Stops on a line: the requested order and its reverse are both shortest.
    costs = straight_line_costs([(0, 0), (1, 0), (2, 0), (3, 0)])

    assert exact_order(costs, fixed_start=False, roundtrip=False) == [0, 1, 2, 3]
    assert nearest_neighbor_two_opt(costs, fixed_start=False, roundtrip=False) == [0, 1, 2, 3]


def test_two_opt_improves_a_greedy_order_that_doubles_back() -> None:
    costs = straight_line_costs(DOUBLING_BACK_POINTS)
    greedy = _nearest_neighbor(costs, 0)

    order = nearest_neighbor_two_opt(costs, fixed_start=True, roundtrip=False)

    assert order[0] == 0
    assert order_cost(costs, order, roundtrip=False) < order_cost(costs, greedy, roundtrip=False)
    assert order_cost(costs, order, roundtrip=False) == pytest.approx(
        brute_force_cost(costs, fixed_start=True, roundtrip=False),
    )


def test_exact_order_rejects_too_many_stops() -> None:
    count = EXACT_ORDER_MAX_STOPS + 1
    costs = [[1.0] * count for _ in range(count)]

    with pytest.raises(ValueError):
        exact_order(costs, fixed_start=True, roundtrip=False)


def test_exact_order_handles_the_largest_allowed_route() -> None:
    points = [(index * 7 % 11, index * 3 % 11) for index in range(EXACT_ORDER_MAX_STOPS)]
    costs = straight_line_costs(points)

    order = exact_order(costs, fixed_start=True, roundtrip=True)

    assert order[0] == 0
    assert sorted(order) == list(range(EXACT_ORDER_MAX_STOPS))
    heuristic = nearest_neighbor_two_opt(costs, fixed_start=True, roundtrip=True)
    assert order_cost(costs, order, roundtrip=True) <= (
        order_cost(costs, heuristic, roundtrip=True) + 1e-9
    )
