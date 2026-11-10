from decimal import Decimal

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.budgets.repository import BudgetRepository
from app.features.budgets.schemas import (
    BudgetBreakdown,
    BudgetEstimateRequest,
    BudgetEstimateResponse,
)
from app.features.destinations.catalog_selection import (
    require_all_accommodations,
    require_all_destinations,
    require_all_transportations,
    require_rates_belong_to_destinations,
)

ZERO_MONEY = Decimal("0.00")


class BudgetService:
    def __init__(self, session: AsyncSession) -> None:
        self.budgets = BudgetRepository(session)

    async def estimate_budget(
        self,
        data: BudgetEstimateRequest,
    ) -> BudgetEstimateResponse:
        destinations = await self.budgets.list_active_destinations_by_ids(
            list(data.destination_ids),
        )
        require_all_destinations(data.destination_ids, destinations)

        accommodations = await self.budgets.list_available_accommodations_by_ids(
            list(data.accommodation_ids),
        )
        require_all_accommodations(data.accommodation_ids, accommodations)

        transportations = await self.budgets.list_available_transportations_by_ids(
            list(data.transportation_ids),
        )
        require_all_transportations(data.transportation_ids, transportations)

        selected_destination_ids = set(data.destination_ids)
        require_rates_belong_to_destinations(
            accommodations=accommodations,
            transportations=transportations,
            destination_ids=selected_destination_ids,
        )

        unknown_cost_ids = [
            destination.destination_id for destination in destinations
            if destination.estimated_cost is None
        ]
        if unknown_cost_ids:
            raise LakbayAPIError(
                "A budget estimate needs costs for every selected destination.",
                code="destination_cost_unknown",
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                details={"destination_ids": unknown_cost_ids},
            )

        destination_total = _sum_money(
            destination.estimated_cost for destination in destinations
        )
        accommodation_total = _sum_money(
            accommodation.price for accommodation in accommodations
        )
        transportation_total = _sum_money(
            transportation.price for transportation in transportations
        )
        meals_total = _money(
            data.meal_cost_per_day
            * Decimal(data.traveler_count)
            * Decimal(data.day_count)
        )
        miscellaneous_total = _money(data.miscellaneous_cost)
        total_estimated_cost = _money(
            destination_total
            + accommodation_total
            + transportation_total
            + meals_total
            + miscellaneous_total
        )

        remaining_budget = max(
            _money(data.total_budget) - total_estimated_cost,
            ZERO_MONEY,
        )
        over_budget_amount = max(
            total_estimated_cost - _money(data.total_budget),
            ZERO_MONEY,
        )

        return BudgetEstimateResponse(
            total_budget=_money(data.total_budget),
            total_estimated_cost=total_estimated_cost,
            remaining_budget=remaining_budget,
            over_budget_amount=over_budget_amount,
            is_over_budget=over_budget_amount > ZERO_MONEY,
            percent_used=_percent_used(
                total_budget=_money(data.total_budget),
                total_estimated_cost=total_estimated_cost,
            ),
            traveler_count=data.traveler_count,
            day_count=data.day_count,
            breakdown=BudgetBreakdown(
                destinations=destination_total,
                accommodations=accommodation_total,
                transportation=transportation_total,
                meals=meals_total,
                miscellaneous=miscellaneous_total,
            ),
        )


def _sum_money(values) -> Decimal:
    return _money(sum((value or ZERO_MONEY for value in values), ZERO_MONEY))


def _money(value: Decimal) -> Decimal:
    return Decimal(value).quantize(Decimal("0.01"))


def _percent_used(*, total_budget: Decimal, total_estimated_cost: Decimal) -> Decimal:
    if total_budget == ZERO_MONEY:
        if total_estimated_cost == ZERO_MONEY:
            return ZERO_MONEY

        return Decimal("100.00")

    return _money((total_estimated_cost / total_budget) * Decimal("100"))
