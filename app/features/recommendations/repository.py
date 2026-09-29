from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.destinations.models import Destination
from app.features.recommendations.models import (
    DestinationInteraction,
    DestinationPopularity,
    UserPreferenceSignal,
)
from app.features.recommendations.schemas import (
    DestinationInteractionCreate,
    RecommendationRequest,
)


class RecommendationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def create_preference_signal(
        self,
        *,
        user_id: int,
        data: RecommendationRequest,
    ) -> UserPreferenceSignal:
        preference = UserPreferenceSignal(
            user_id=user_id,
            preferred_categories=_normalize_list(data.preferred_categories),
            preferred_vibes=_normalize_list(data.preferred_vibes),
            preferred_activities=_normalize_list(data.preferred_activities),
            preferred_districts=_normalize_list(data.preferred_districts),
            budget_class=_normalize_optional(data.budget_class),
            difficulty_level=_normalize_optional(data.difficulty_level),
            stay_duration_type=_normalize_optional(data.stay_duration_type),
            max_estimated_cost=data.max_estimated_cost,
            requires_kid_friendly=data.requires_kid_friendly,
            requires_wheelchair_accessible=data.requires_wheelchair_accessible,
            requires_pet_friendly=data.requires_pet_friendly,
            requires_elderly_friendly=data.requires_elderly_friendly,
            family_friendly=data.family_friendly,
            couple_friendly=data.couple_friendly,
            group_friendly=data.group_friendly,
        )
        self.session.add(preference)
        await self.session.flush()

        return preference

    async def get_latest_preference(
        self,
        *,
        user_id: int,
    ) -> UserPreferenceSignal | None:
        result = await self.session.execute(
            select(UserPreferenceSignal)
            .where(UserPreferenceSignal.user_id == user_id)
            .order_by(
                UserPreferenceSignal.created_at.desc(),
                UserPreferenceSignal.preference_signal_id.desc(),
            )
            .limit(1)
        )

        return result.scalar_one_or_none()

    async def list_active_destinations(self) -> list[Destination]:
        result = await self.session.execute(
            select(Destination)
            .where(Destination.is_active.is_(True))
            .order_by(Destination.name.asc())
        )

        return list(result.scalars().all())

    async def get_active_destination(
        self,
        *,
        destination_id: int,
    ) -> Destination | None:
        result = await self.session.execute(
            select(Destination).where(
                Destination.destination_id == destination_id,
                Destination.is_active.is_(True),
            )
        )

        return result.scalar_one_or_none()

    async def list_popularity(self) -> dict[int, DestinationPopularity]:
        result = await self.session.execute(select(DestinationPopularity))

        return {
            popularity.destination_id: popularity
            for popularity in result.scalars().all()
        }

    async def get_popularity(
        self,
        *,
        destination_id: int,
    ) -> DestinationPopularity | None:
        result = await self.session.execute(
            select(DestinationPopularity).where(
                DestinationPopularity.destination_id == destination_id,
            )
        )

        return result.scalar_one_or_none()

    async def get_or_create_popularity(
        self,
        *,
        destination_id: int,
    ) -> DestinationPopularity:
        popularity = await self.get_popularity(destination_id=destination_id)

        if popularity is not None:
            return popularity

        popularity = DestinationPopularity(destination_id=destination_id)
        self.session.add(popularity)
        await self.session.flush()

        return popularity

    async def create_interaction(
        self,
        *,
        user_id: int,
        destination_id: int,
        data: DestinationInteractionCreate,
    ) -> DestinationInteraction:
        interaction = DestinationInteraction(
            user_id=user_id,
            destination_id=destination_id,
            interaction_type=data.interaction_type,
            rating=data.rating,
            notes=data.notes,
        )
        self.session.add(interaction)
        await self.session.flush()

        return interaction

    async def get_user_interaction(
        self,
        *,
        user_id: int,
        destination_id: int,
        interaction_type: str,
    ) -> DestinationInteraction | None:
        result = await self.session.execute(
            select(DestinationInteraction)
            .where(
                DestinationInteraction.user_id == user_id,
                DestinationInteraction.destination_id == destination_id,
                DestinationInteraction.interaction_type == interaction_type,
            )
            .order_by(
                DestinationInteraction.created_at.desc(),
                DestinationInteraction.interaction_id.desc(),
            )
            .limit(1)
        )

        return result.scalar_one_or_none()

    async def update_interaction(
        self,
        interaction: DestinationInteraction,
        data: DestinationInteractionCreate,
    ) -> DestinationInteraction:
        interaction.rating = data.rating
        interaction.notes = data.notes
        await self.session.flush()

        return interaction

    async def list_destination_interactions(
        self,
        *,
        destination_id: int,
    ) -> list[DestinationInteraction]:
        result = await self.session.execute(
            select(DestinationInteraction).where(
                DestinationInteraction.destination_id == destination_id,
            )
        )

        return list(result.scalars().all())


def _normalize_optional(value: str | None) -> str | None:
    if value is None:
        return None

    normalized = value.strip().lower()

    return normalized or None


def _normalize_list(values: list[str]) -> list[str]:
    normalized = []

    for value in values:
        cleaned = value.strip().lower()

        if cleaned and cleaned not in normalized:
            normalized.append(cleaned)

    return normalized
