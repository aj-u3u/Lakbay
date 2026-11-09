"""Translate OSM tags into reviewable suggestions without writing catalog data."""

from collections.abc import Callable
from math import isfinite
from typing import NamedTuple

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.destinations.candidate_repository import CandidateRepository, distance_meters
from app.features.destinations.models import DestinationCandidate
from app.features.destinations.osm_schemas import OSMMatch, OSMSuggestion, OSMSuggestionResponse
from app.integrations.osm.client import OSMClient


MAX_MATCHES = 10
# Tags read, in order, to describe what kind of place an OSM object is.
_CATEGORY_KEYS = ("tourism", "leisure", "natural", "historic", "amenity")
# OSM tags whose meaning matches a word already used as a catalog category. Other
# tags are returned only as `category_hint`, because admins enter the category.
_CATALOG_CATEGORIES = {
    ("natural", "beach"): "beach",
    ("natural", "waterfall"): "waterfall",
    ("waterway", "waterfall"): "waterfall",
    ("natural", "hot_spring"): "hot spring",
    ("natural", "peak"): "mountain",
    ("natural", "volcano"): "mountain",
    ("natural", "cape"): "scenic cape",
    ("place", "island"): "island",
    ("place", "islet"): "island",
    ("tourism", "museum"): "museum",
    ("tourism", "zoo"): "wildlife",
    ("leisure", "park"): "park",
    ("leisure", "nature_reserve"): "nature park",
    ("leisure", "water_park"): "water park",
    ("leisure", "beach_resort"): "beach resort",
    ("amenity", "place_of_worship"): "religious landmark",
}


class _Place(NamedTuple):
    osm_type: str
    osm_id: int
    osm_url: str
    name: str
    lat: float
    lng: float
    category: tuple[str, str] | None


class OSMLookupService:
    def __init__(
        self, session: AsyncSession, before_provider_call: Callable[[], None] | None = None
    ) -> None:
        self.candidates = CandidateRepository(session)
        self.osm = OSMClient(before_provider_call)

    async def search(self, *, name: str, lat: float, lng: float, radius_m: int) -> list[OSMMatch]:
        elements = await self.osm.search(name=name, lat=lat, lng=lng, radius_m=radius_m)
        places = [place for row in elements if (place := _place(row)) is not None]
        wanted = name.strip().casefold()
        # Exact names first, then the places closest to the admin's approximate point.
        places.sort(key=lambda place: (
            place.name.casefold() != wanted,
            distance_meters(lat, lng, place.lat, place.lng),
            place.osm_id,
        ))
        places = places[:MAX_MATCHES]

        candidates = {
            (candidate.osm_type, candidate.osm_id): candidate
            for candidate in await self.candidates.list_by_osm_ids([place.osm_id for place in places])
        }
        destinations = await self.candidates.nearby_same_names(
            [(place.name, place.lat, place.lng) for place in places]
        )
        matches = []
        for place, destination in zip(places, destinations):
            existing = candidates.get((place.osm_type, place.osm_id))
            matches.append(OSMMatch(
                osm_type=place.osm_type, osm_id=place.osm_id, osm_url=place.osm_url,
                name=place.name, lat=place.lat, lng=place.lng,
                category=place.category[1] if place.category else None,
                source_tag=f"{place.category[0]}={place.category[1]}" if place.category else None,
                existing_candidate_id=existing.candidate_id if existing else None,
                existing_candidate_status=existing.review_status if existing else None,
                existing_destination_id=destination.destination_id if destination else None,
            ))
        return matches

    async def place_suggestions(self, *, osm_type: str, osm_id: int) -> OSMSuggestionResponse:
        return await self._suggestions(osm_type, osm_id, candidate=None)

    async def candidate_suggestions(self, candidate_id: int) -> OSMSuggestionResponse:
        candidate = await self.candidates.get(candidate_id)
        if candidate is None:
            raise LakbayAPIError(
                "Destination candidate was not found.",
                code="candidate_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )
        if candidate.review_status != "staged":
            raise LakbayAPIError(
                "Only staged candidates can be reviewed.",
                code="candidate_not_staged",
                status_code=status.HTTP_409_CONFLICT,
            )
        return await self._suggestions(candidate.osm_type, candidate.osm_id, candidate=candidate)

    async def _suggestions(
        self, osm_type: str, osm_id: int, *, candidate: DestinationCandidate | None
    ) -> OSMSuggestionResponse:
        row = await self.osm.get(osm_type, osm_id)
        if row is None:
            raise LakbayAPIError("OSM place was not found.", code="osm_place_not_found", status_code=status.HTTP_404_NOT_FOUND)
        tags = row.get("tags") if isinstance(row.get("tags"), dict) else {}
        point = _point(row)
        url = f"https://www.openstreetmap.org/{osm_type}/{osm_id}"
        fields: list[OSMSuggestion] = []

        def current(field: str) -> object:
            return getattr(candidate, field, None) if candidate else None

        def add(field: str, value: object, source_tag: str, max_length: int = 500) -> None:
            cleaned = _clean(value, max_length)
            if cleaned is not None:
                fields.append(OSMSuggestion(
                    field=field, value=cleaned, source_tag=source_tag,
                    source_url=url, current_value=current(field),
                ))

        add("name", tags.get("name"), "name", 255)
        if point:
            for field, value in zip(("lat", "lng"), point):
                fields.append(OSMSuggestion(
                    field=field, value=value, source_tag="OSM geometry center",
                    source_url=url, current_value=current(field),
                ))
        catalog_category = _catalog_category(tags)
        if catalog_category:
            key, value, category = catalog_category
            add("category", category, f"{key}={value}")
        add("description", tags.get("description:en") or tags.get("description"), "description:en" if tags.get("description:en") else "description", 4000)
        add("operating_hours", tags.get("opening_hours"), "opening_hours", 255)
        address = _address(tags)
        if address:
            add("location", address, "addr:*", 500)
        raw_category = _category_with_tag(tags)
        return OSMSuggestionResponse(
            osm_type=osm_type, osm_id=osm_id, osm_url=url,
            candidate_id=candidate.candidate_id if candidate else None,
            suggestions=fields,
            website=_clean(tags.get("website"), 2048),
            fee_hint=_clean(tags.get("fee"), 255),
            category_hint=f"{raw_category[0]}={raw_category[1]}" if raw_category else None,
        )


def _place(row: dict) -> _Place | None:
    identity = _identity(row)
    point = _point(row)
    tags = row.get("tags")
    if identity is None or point is None or not isinstance(tags, dict):
        return None
    name = _clean(tags.get("name"), 255)
    if name is None:
        return None
    osm_type, osm_id, osm_url = identity
    return _Place(osm_type, osm_id, osm_url, name, point[0], point[1], _category_with_tag(tags))


def _identity(row: dict) -> tuple[str, int, str] | None:
    osm_type, osm_id = row.get("type"), row.get("id")
    if osm_type not in {"node", "way", "relation"} or type(osm_id) is not int or osm_id < 1:
        return None
    return osm_type, osm_id, f"https://www.openstreetmap.org/{osm_type}/{osm_id}"


def _point(row: dict) -> tuple[float, float] | None:
    point = row if row.get("type") == "node" else row.get("center")
    if not isinstance(point, dict):
        return None
    lat, lng = point.get("lat"), point.get("lon")
    if not isinstance(lat, (int, float)) or not isinstance(lng, (int, float)):
        return None
    if not isfinite(lat) or not isfinite(lng) or not (-90 <= lat <= 90 and -180 <= lng <= 180):
        return None
    return float(lat), float(lng)


def _clean(value: object, limit: int) -> str | None:
    if not isinstance(value, str):
        return None
    value = value.strip()
    return value if value and len(value) <= limit else None


def _category_with_tag(tags: dict) -> tuple[str, str] | None:
    for key in _CATEGORY_KEYS:
        value = _clean(tags.get(key), 500)
        if value:
            return key, value
    return None


def _catalog_category(tags: dict) -> tuple[str, str, str] | None:
    for (key, value), category in _CATALOG_CATEGORIES.items():
        if tags.get(key) == value:
            return key, value, category
    return None


def _address(tags: dict) -> str | None:
    full = _clean(tags.get("addr:full"), 500)
    if full:
        return full
    parts = [
        _clean(tags.get(key), 100)
        for key in ("addr:housenumber", "addr:street", "addr:city", "addr:province")
    ]
    return ", ".join(part for part in parts if part) or None
