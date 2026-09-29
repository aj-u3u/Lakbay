from geoalchemy2.elements import WKTElement
from sqlalchemy import Select, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.destinations.models import Destination
from app.features.destinations.schemas import DestinationCreate, DestinationListQuery


class DestinationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list(self, filters: DestinationListQuery) -> list[Destination]:
        statement = (
            self._apply_filters(select(Destination), filters)
            .order_by(Destination.name.asc())
            .offset(filters.offset)
            .limit(filters.limit)
        )
        result = await self.session.execute(statement)

        return list(result.scalars().all())

    async def get_by_id(
        self,
        destination_id: int,
        *,
        include_inactive: bool = False,
    ) -> Destination | None:
        statement = select(Destination).where(
            Destination.destination_id == destination_id,
        )

        if not include_inactive:
            statement = statement.where(Destination.is_active.is_(True))

        result = await self.session.execute(statement)

        return result.scalar_one_or_none()

    async def create(self, data: DestinationCreate) -> Destination:
        destination_values = data.model_dump()
        geom = self._build_geom(lat=data.lat, lng=data.lng)

        if geom is not None:
            destination_values["geom"] = geom

        destination = Destination(**destination_values)
        self.session.add(destination)
        await self.session.flush()

        return destination

    async def update(
        self,
        destination: Destination,
        values: dict,
    ) -> Destination:
        for field, value in values.items():
            setattr(destination, field, value)

        if "lat" in values or "lng" in values:
            geom = self._build_geom(
                lat=destination.lat,
                lng=destination.lng,
            )

            if geom is not None:
                destination.geom = geom

        await self.session.flush()

        return destination

    async def deactivate(self, destination: Destination) -> Destination:
        destination.is_active = False
        await self.session.flush()

        return destination

    def _apply_filters(
        self,
        statement: Select[tuple[Destination]],
        filters: DestinationListQuery,
    ) -> Select[tuple[Destination]]:
        if not filters.include_inactive:
            statement = statement.where(Destination.is_active.is_(True))

        if filters.search:
            search_pattern = f"%{filters.search.strip()}%"
            statement = statement.where(
                or_(
                    Destination.name.ilike(search_pattern),
                    Destination.description.ilike(search_pattern),
                    Destination.location.ilike(search_pattern),
                    Destination.category.ilike(search_pattern),
                    Destination.activities.ilike(search_pattern),
                )
            )

        if filters.district:
            statement = statement.where(Destination.district.ilike(filters.district))

        if filters.category:
            statement = statement.where(Destination.category.ilike(filters.category))

        if filters.budget_class:
            statement = statement.where(
                Destination.budget_class.ilike(filters.budget_class),
            )

        if filters.difficulty_level:
            statement = statement.where(
                Destination.difficulty_level.ilike(filters.difficulty_level),
            )

        if filters.kid_friendly is not None:
            statement = statement.where(
                Destination.is_kid_friendly.is_(filters.kid_friendly),
            )

        if filters.wheelchair_accessible is not None:
            statement = statement.where(
                Destination.is_wheelchair_accessible.is_(
                    filters.wheelchair_accessible,
                ),
            )

        if filters.pet_friendly is not None:
            statement = statement.where(
                Destination.is_pet_friendly.is_(filters.pet_friendly),
            )

        if filters.family_friendly is not None:
            statement = statement.where(
                Destination.family_friendly.is_(filters.family_friendly),
            )

        if filters.couple_friendly is not None:
            statement = statement.where(
                Destination.couple_friendly.is_(filters.couple_friendly),
            )

        if filters.group_friendly is not None:
            statement = statement.where(
                Destination.group_friendly.is_(filters.group_friendly),
            )

        return statement

    def _build_geom(self, *, lat: float, lng: float) -> WKTElement | None:
        bind = self.session.get_bind()

        if bind.dialect.name != "postgresql":
            return None

        return WKTElement(f"POINT({lng} {lat})", srid=4326)
