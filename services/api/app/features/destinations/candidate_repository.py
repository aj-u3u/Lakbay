from math import asin, cos, radians, sin, sqrt

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.destinations.models import Destination, DestinationCandidate


class CandidateRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list(
        self, *, status: str | None, limit: int, offset: int
    ) -> list[DestinationCandidate]:
        query = select(DestinationCandidate)
        if status is not None:
            query = query.where(DestinationCandidate.review_status == status)
        query = query.order_by(DestinationCandidate.candidate_id).offset(offset).limit(limit)
        result = await self.session.execute(query)
        return list(result.scalars().all())

    async def get(self, candidate_id: int, *, lock: bool = False) -> DestinationCandidate | None:
        query = select(DestinationCandidate).where(DestinationCandidate.candidate_id == candidate_id)
        if lock:
            query = query.with_for_update()
        result = await self.session.execute(query)
        return result.scalar_one_or_none()

    async def get_by_osm_identity(self, osm_type: str, osm_id: int) -> DestinationCandidate | None:
        result = await self.session.execute(
            select(DestinationCandidate).where(
                DestinationCandidate.osm_type == osm_type,
                DestinationCandidate.osm_id == osm_id,
            )
        )
        return result.scalar_one_or_none()

    async def list_by_osm_ids(self, osm_ids: list[int]) -> list[DestinationCandidate]:
        """Return candidates for these OSM IDs; callers match the OSM type themselves."""
        if not osm_ids:
            return []
        result = await self.session.execute(
            select(DestinationCandidate).where(DestinationCandidate.osm_id.in_(osm_ids))
        )
        return list(result.scalars().all())

    async def matching_local_places(self, name: str, lat: float, lng: float, radius_m: int) -> list[DestinationCandidate]:
        """Use reviewed OSM identities as a search fallback when Overpass is down."""
        result = await self.session.execute(
            select(DestinationCandidate).where(
                func.lower(func.trim(DestinationCandidate.name)) == name.strip().lower(),
                DestinationCandidate.review_status != "rejected",
            )
        )
        return [
            candidate for candidate in result.scalars()
            if distance_meters(lat, lng, candidate.lat, candidate.lng) <= radius_m
        ]

    async def nearby_same_name(self, candidate: DestinationCandidate) -> Destination | None:
        return (await self.nearby_same_names([(candidate.name, candidate.lat, candidate.lng)]))[0]

    async def nearby_same_names(
        self, places: list[tuple[str, float, float]]
    ) -> list[Destination | None]:
        """Match each (name, lat, lng) to a same-name destination within 250 m, in one query."""
        names = {name.strip().lower() for name, _, _ in places}
        if not names:
            return []
        result = await self.session.execute(
            select(Destination).where(func.lower(func.trim(Destination.name)).in_(names))
        )
        by_name: dict[str, list[Destination]] = {}
        for destination in result.scalars():
            by_name.setdefault(destination.name.strip().lower(), []).append(destination)
        return [
            next(
                (
                    destination
                    for destination in by_name.get(name.strip().lower(), [])
                    if distance_meters(lat, lng, destination.lat, destination.lng) <= 250
                ),
                None,
            )
            for name, lat, lng in places
        ]


def distance_meters(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    d_lat = radians(lat2 - lat1)
    d_lng = radians(lng2 - lng1)
    a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lng / 2) ** 2
    return 2 * 6_371_000 * asin(min(1, sqrt(a)))
