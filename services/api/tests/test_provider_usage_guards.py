from concurrent.futures import ThreadPoolExecutor

from app.core.exceptions import LakbayAPIError
from app.core.provider_usage import SlidingWindowLimiter


def test_concurrent_reservations_never_exceed_shared_process_limit():
    limiter = SlidingWindowLimiter()

    def attempt(_):
        try:
            limiter.reserve(
                "provider:all",
                limit=5,
                code="provider_limit",
                message="Busy",
            )
            return True
        except LakbayAPIError:
            return False

    with ThreadPoolExecutor(max_workers=20) as pool:
        outcomes = list(pool.map(attempt, range(50)))

    assert sum(outcomes) == 5


def test_rejected_multi_rule_reservation_does_not_consume_other_rule():
    limiter = SlidingWindowLimiter()
    limiter.reserve("app", limit=1, code="limit", message="Busy")

    try:
        limiter.reserve_many(
            [("user", 1, 60, 1), ("app", 1, 60, 1)],
            code="limit",
            message="Busy",
        )
    except LakbayAPIError:
        pass
    else:
        raise AssertionError("App limit should reject the reservation")

    limiter.reserve("user", limit=1, code="limit", message="Busy")
