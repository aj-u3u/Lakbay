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

    async def nearby_same_name(self, candidate: DestinationCandidate) -> Destination | None:
        result = await self.session.execute(
            select(Destination).where(
                func.lower(func.trim(Destination.name)) == candidate.name.strip().lower()
            )
        )
        for destination in result.scalars():
            if _distance_meters(candidate.lat, candidate.lng, destination.lat, destination.lng) <= 250:
                return destination
        return None


def _distance_meters(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    d_lat = radians(lat2 - lat1)
    d_lng = radians(lng2 - lng1)
    a = sin(d_lat / 2) ** 2 + cos(radians(lat1)) * cos(radians(lat2)) * sin(d_lng / 2) ** 2
    return 2 * 6_371_000 * asin(min(1, sqrt(a)))
