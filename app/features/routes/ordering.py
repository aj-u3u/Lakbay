"""Choose the order in which a route visits its stops.

Costs are a square table where ``costs[i][j]`` is the travel cost from stop
``i`` to stop ``j``, such as OSRM travel seconds or Haversine kilometers. The
table may be asymmetric. Stop 0 is the traveler's start when ``fixed_start``
is true, and ``roundtrip`` adds the leg from the last stop back to stop 0.

Two methods are used, chosen by the route service:

- ``exact_order``: Held-Karp dynamic programming. It returns the order with the
  lowest total cost among all possible orders, in O(n^2 * 2^n) steps, so it is
  limited to small stop counts.
- ``nearest_neighbor_two_opt``: a greedy nearest-stop order improved by 2-opt,
  which reverses a section of the route whenever that lowers the total cost
  (removing crossed paths). It is fast for any size but not guaranteed optimal.

Both keep the requested order (0, 1, 2, ...) when it costs no more than the
best order found, so travelers do not see their list reshuffled for nothing.
"""

from collections.abc import Sequence

# The default route limit of 10 destinations plus the traveler's start.
EXACT_ORDER_MAX_STOPS = 11
# Costs closer than this are treated as equal, for floating-point safety.
_TIE_TOLERANCE = 1e-6


def order_cost(costs: Sequence[Sequence[float]], order: Sequence[int], *, roundtrip: bool) -> float:
    total = sum(costs[start][end] for start, end in zip(order, order[1:]))
    if roundtrip and len(order) > 1:
        total += costs[order[-1]][order[0]]
    return total


def exact_order(
    costs: Sequence[Sequence[float]], *, fixed_start: bool, roundtrip: bool,
) -> list[int]:
    count = len(costs)
    if count > EXACT_ORDER_MAX_STOPS:
        raise ValueError("Too many stops for an exact order search.")
    if count <= 1:
        return list(range(count))
    # Rotating a closed loop does not change its cost, so stop 0 may stay first.
    fixed_start = fixed_start or roundtrip

    infinity = float("inf")
    full = (1 << count) - 1
    # best[mask][last]: lowest cost of a path that visits the stops in mask and
    # ends at last; previous[mask][last] is the stop visited just before it.
    best = [[infinity] * count for _ in range(1 << count)]
    previous = [[-1] * count for _ in range(1 << count)]
    for start in ([0] if fixed_start else range(count)):
        best[1 << start][start] = 0.0

    for mask in range(1, full + 1):
        if fixed_start and not mask & 1:
            continue
        row = best[mask]
        for last in range(count):
            cost = row[last]
            if cost == infinity:
                continue
            from_last = costs[last]
            for following in range(count):
                bit = 1 << following
                if mask & bit:
                    continue
                candidate = cost + from_last[following]
                if candidate < best[mask | bit][following]:
                    best[mask | bit][following] = candidate
                    previous[mask | bit][following] = last

    end, end_cost = -1, infinity
    for last in range(count):
        total = best[full][last] + (costs[last][0] if roundtrip else 0.0)
        if total < end_cost:
            end, end_cost = last, total

    order, mask = [], full
    while end != -1:
        order.append(end)
        end, mask = previous[mask][end], mask ^ (1 << end)
    order.reverse()
    return _keep_requested_on_tie(costs, order, roundtrip=roundtrip)


def nearest_neighbor_two_opt(
    costs: Sequence[Sequence[float]], *, fixed_start: bool, roundtrip: bool,
) -> list[int]:
    count = len(costs)
    if count <= 1:
        return list(range(count))
    fixed_start = fixed_start or roundtrip

    found: list[int] | None = None
    for start in ([0] if fixed_start else range(count)):
        order = _two_opt(
            costs, _nearest_neighbor(costs, start),
            fixed_start=fixed_start, roundtrip=roundtrip,
        )
        if found is None or (
            order_cost(costs, order, roundtrip=roundtrip)
            < order_cost(costs, found, roundtrip=roundtrip) - _TIE_TOLERANCE
        ):
            found = order
    return _keep_requested_on_tie(costs, found, roundtrip=roundtrip)


def _nearest_neighbor(costs: Sequence[Sequence[float]], start: int) -> list[int]:
    order = [start]
    remaining = [index for index in range(len(costs)) if index != start]
    while remaining:
        # Ties go to the earlier listed stop.
        following = min(remaining, key=lambda index: costs[order[-1]][index])
        order.append(following)
        remaining.remove(following)
    return order


def _two_opt(
    costs: Sequence[Sequence[float]], order: list[int], *, fixed_start: bool, roundtrip: bool,
) -> list[int]:
    first = 1 if fixed_start else 0
    current = order_cost(costs, order, roundtrip=roundtrip)
    improved = True
    while improved:
        improved = False
        for left in range(first, len(order) - 1):
            for right in range(left + 1, len(order)):
                candidate = order[:left] + order[left:right + 1][::-1] + order[right + 1:]
                cost = order_cost(costs, candidate, roundtrip=roundtrip)
                if cost < current - _TIE_TOLERANCE:
                    order, current, improved = candidate, cost, True
    return order


def _keep_requested_on_tie(
    costs: Sequence[Sequence[float]], order: list[int], *, roundtrip: bool,
) -> list[int]:
    requested = list(range(len(costs)))
    if order_cost(costs, requested, roundtrip=roundtrip) <= (
        order_cost(costs, order, roundtrip=roundtrip) + _TIE_TOLERANCE
    ):
        return requested
    return order
