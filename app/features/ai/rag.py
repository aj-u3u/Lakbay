import hashlib
import math
import re
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.accommodations.models import Accommodation
from app.features.destinations.models import Destination
from app.features.transportations.models import Transportation


VECTOR_DIMENSION = 384
MIN_RAG_SCORE = 0.05
TOKEN_PATTERN = re.compile(r"[a-z0-9]+")

STOPWORDS = {
    "a",
    "about",
    "and",
    "any",
    "are",
    "around",
    "as",
    "at",
    "be",
    "can",
    "could",
    "for",
    "from",
    "give",
    "help",
    "how",
    "i",
    "in",
    "is",
    "it",
    "me",
    "my",
    "of",
    "on",
    "or",
    "our",
    "plan",
    "please",
    "should",
    "show",
    "that",
    "the",
    "this",
    "to",
    "trip",
    "travel",
    "want",
    "we",
    "what",
    "where",
    "with",
}

SYNONYMS = {
    "affordable": {"budget", "cheap", "lowcost"},
    "beach": {"coast", "coastal", "island", "swimming", "sea"},
    "budget": {"affordable", "cheap", "lowcost"},
    "cheap": {"affordable", "budget", "lowcost"},
    "child": {"children", "family", "kid", "kids"},
    "children": {"child", "family", "kid", "kids"},
    "commute": {"transport", "transportation", "route"},
    "elderly": {"senior", "accessible", "easy"},
    "family": {"child", "children", "kid", "kids"},
    "food": {"meal", "restaurant", "cafe", "eat"},
    "hotel": {"accommodation", "room", "stay"},
    "kid": {"child", "children", "family", "kids"},
    "kids": {"child", "children", "family", "kid"},
    "mountain": {"hike", "hiking", "trail", "nature"},
    "rain": {"weather", "umbrella", "indoor"},
    "relax": {"relaxed", "relaxing", "slow"},
    "room": {"accommodation", "hotel", "stay"},
    "route": {"commute", "transport", "transportation"},
    "stay": {"accommodation", "hotel", "room"},
    "transport": {"commute", "route", "transportation"},
    "transportation": {"commute", "route", "transport"},
    "waterfall": {"falls", "nature", "swimming"},
}


@dataclass(frozen=True)
class RagDocument:
    source: str
    source_id: int
    title: str
    text: str
    payload: dict[str, Any]
    vector: tuple[float, ...]
    terms: frozenset[str]


@dataclass(frozen=True)
class RagMatch:
    source: str
    source_id: int
    title: str
    score: float
    payload: dict[str, Any]

    def to_prompt_dict(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "source_id": self.source_id,
            "title": self.title,
            "score": round(self.score, 4),
            "facts": self.payload,
        }

    def to_response_dict(self) -> dict[str, Any]:
        return {
            "source": self.source,
            "source_id": self.source_id,
            "title": self.title,
            "score": round(self.score, 4),
            "facts": self.payload,
        }


class VectorRAGRetriever:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def retrieve(self, query: str, *, limit: int = 6) -> list[RagMatch]:
        query_terms = _terms(query)
        if not query_terms:
            return []

        query_vector = _embed_terms(query_terms)
        documents = await self._load_documents()
        matches = [
            RagMatch(
                source=document.source,
                source_id=document.source_id,
                title=document.title,
                score=_score(
                    query_vector=query_vector,
                    query_terms=query_terms,
                    document=document,
                ),
                payload=document.payload,
            )
            for document in documents
        ]

        matches = [match for match in matches if match.score >= MIN_RAG_SCORE]
        matches.sort(key=lambda match: match.score, reverse=True)

        if _is_region_wide_query(query_terms):
            return _diversify_by_district(matches, limit=limit)

        return matches[:limit]

    async def _load_documents(self) -> list[RagDocument]:
        destination_result = await self.session.execute(
            select(Destination).where(Destination.is_active.is_(True)),
        )
        destinations = list(destination_result.scalars().all())
        destinations_by_id = {
            destination.destination_id: destination for destination in destinations
        }

        accommodation_result = await self.session.execute(
            select(Accommodation).where(Accommodation.is_available.is_(True)),
        )
        accommodations = [
            item
            for item in accommodation_result.scalars().all()
            if item.destination_id in destinations_by_id
        ]

        transportation_result = await self.session.execute(
            select(Transportation).where(Transportation.is_available.is_(True)),
        )
        transportations = [
            item
            for item in transportation_result.scalars().all()
            if item.destination_id in destinations_by_id
        ]

        documents: list[RagDocument] = [
            _destination_document(destination) for destination in destinations
        ]
        documents.extend(
            _accommodation_document(
                accommodation,
                destination=destinations_by_id[accommodation.destination_id],
            )
            for accommodation in accommodations
        )
        documents.extend(
            _transportation_document(
                transportation,
                destination=destinations_by_id[transportation.destination_id],
            )
            for transportation in transportations
        )

        return documents


def _destination_document(destination: Destination) -> RagDocument:
    payload = {
        "destination_id": destination.destination_id,
        "name": destination.name,
        "description": destination.description,
        "district": destination.district,
        "location": destination.location,
        "category": destination.category,
        "vibes": destination.vibes,
        "activities": destination.activities,
        "estimated_cost": _money(destination.estimated_cost),
        "entrance_fee": destination.entrance_fee,
        "overnight_fee": destination.overnight_fee,
        "operating_hours": destination.operating_hours,
        "best_time_to_visit": destination.best_time_to_visit,
        "how_to_get_there": destination.how_to_get_there,
        "estimated_travel_time": destination.estimated_travel_time,
        "travel_notes": destination.travel_notes,
        "what_to_bring": destination.what_to_bring,
        "budget_class": destination.budget_class,
        "crowd_level": destination.crowd_level,
        "difficulty_level": destination.difficulty_level,
        "stay_duration_type": destination.stay_duration_type,
        "transport_accessibility": destination.transport_accessibility,
        "family_friendly": destination.family_friendly,
        "group_friendly": destination.group_friendly,
        "kid_friendly": destination.is_kid_friendly,
        "wheelchair_accessible": destination.is_wheelchair_accessible,
        "pet_friendly": destination.is_pet_friendly,
        "elderly_friendly": destination.is_elderly_friendly,
    }
    text = _join_text(
        "destination",
        destination.name,
        destination.description,
        destination.district,
        destination.location,
        destination.category,
        destination.vibes,
        destination.activities,
        destination.best_time_to_visit,
        destination.how_to_get_there,
        destination.estimated_travel_time,
        destination.travel_notes,
        destination.what_to_bring,
        destination.budget_class,
        destination.crowd_level,
        destination.difficulty_level,
        destination.stay_duration_type,
        destination.transport_accessibility,
        _flag_text("family friendly", destination.family_friendly),
        _flag_text("group friendly", destination.group_friendly),
        _flag_text("kid friendly", destination.is_kid_friendly),
        _flag_text("wheelchair accessible", destination.is_wheelchair_accessible),
        _flag_text("pet friendly", destination.is_pet_friendly),
        _flag_text("elderly friendly", destination.is_elderly_friendly),
    )

    return _document(
        source="destination",
        source_id=destination.destination_id,
        title=destination.name,
        text=text,
        payload=_compact_dict(payload),
    )


def _accommodation_document(
    accommodation: Accommodation,
    *,
    destination: Destination,
) -> RagDocument:
    payload = {
        "accommodation_id": accommodation.accommodation_id,
        "destination_id": accommodation.destination_id,
        "destination_name": destination.name,
        "name": accommodation.name,
        "room_type": accommodation.room_type,
        "price": _money(accommodation.price),
        "capacity": accommodation.capacity,
        "description": accommodation.description,
    }
    text = _join_text(
        "accommodation",
        accommodation.name,
        accommodation.room_type,
        accommodation.description,
        destination.name,
        destination.district,
        destination.location,
        destination.category,
        f"capacity {accommodation.capacity}",
        f"price {_money(accommodation.price)}",
    )

    return _document(
        source="accommodation",
        source_id=accommodation.accommodation_id,
        title=accommodation.name,
        text=text,
        payload=_compact_dict(payload),
    )


def _transportation_document(
    transportation: Transportation,
    *,
    destination: Destination,
) -> RagDocument:
    payload = {
        "transportation_id": transportation.transportation_id,
        "destination_id": transportation.destination_id,
        "destination_name": destination.name,
        "vehicle_type": transportation.vehicle_type,
        "transport_mode": transportation.transport_mode,
        "route_from": transportation.route_from,
        "route_to": transportation.route_to,
        "price": _money(transportation.price),
        "duration_minutes": transportation.duration_minutes,
        "duration_text": transportation.duration_text,
        "notes": transportation.notes,
    }
    text = _join_text(
        "transportation",
        transportation.vehicle_type,
        transportation.transport_mode,
        transportation.route_from,
        transportation.route_to,
        transportation.duration_text,
        transportation.notes,
        destination.name,
        destination.district,
        destination.location,
        f"price {_money(transportation.price)}",
        f"duration {transportation.duration_minutes or ''} minutes",
    )

    return _document(
        source="transportation",
        source_id=transportation.transportation_id,
        title=f"{transportation.vehicle_type}: {transportation.route_from} to {transportation.route_to}",
        text=text,
        payload=_compact_dict(payload),
    )


def _document(
    *,
    source: str,
    source_id: int,
    title: str,
    text: str,
    payload: dict[str, Any],
) -> RagDocument:
    terms = _terms(text)

    return RagDocument(
        source=source,
        source_id=source_id,
        title=title,
        text=text,
        payload=payload,
        vector=_embed_terms(terms),
        terms=frozenset(terms),
    )


def _terms(text: str) -> list[str]:
    terms: list[str] = []
    for token in TOKEN_PATTERN.findall(text.lower()):
        if token in STOPWORDS or len(token) < 2:
            continue
        terms.append(token)
        terms.extend(SYNONYMS.get(token, set()))

        if token.endswith("ies") and len(token) > 4:
            terms.append(f"{token[:-3]}y")
        elif token.endswith("ing") and len(token) > 5:
            terms.append(token[:-3])
        elif token.endswith("s") and len(token) > 3:
            terms.append(token[:-1])

    return terms


def _embed_terms(terms: list[str]) -> tuple[float, ...]:
    vector = [0.0] * VECTOR_DIMENSION

    for term in terms:
        digest = hashlib.sha256(term.encode("utf-8")).digest()
        index = int.from_bytes(digest[:4], "big") % VECTOR_DIMENSION
        vector[index] += 1.0

    norm = math.sqrt(sum(value * value for value in vector))
    if norm == 0:
        return tuple(vector)

    return tuple(value / norm for value in vector)


def _score(
    *,
    query_vector: tuple[float, ...],
    query_terms: list[str],
    document: RagDocument,
) -> float:
    vector_score = sum(
        query_value * document_value
        for query_value, document_value in zip(query_vector, document.vector)
    )
    query_term_set = set(query_terms)
    overlap_count = len(query_term_set.intersection(document.terms))
    overlap_score = overlap_count / max(math.sqrt(len(query_term_set) + 1), 1.0)

    source_boost = 0.02 if document.source == "destination" else 0.0

    return (vector_score * 0.82) + (overlap_score * 0.16) + source_boost


def _is_region_wide_query(query_terms: list[str]) -> bool:
    query_term_set = set(query_terms)

    return "davao" in query_term_set and bool(
        query_term_set.intersection({"region", "province", "provinces", "area", "areas"})
    )


def _diversify_by_district(
    matches: list[RagMatch],
    *,
    limit: int,
) -> list[RagMatch]:
    selected: list[RagMatch] = []
    selected_keys: set[tuple[str, int]] = set()
    seen_districts: set[str] = set()

    for match in matches:
        district = match.payload.get("district")
        if match.source != "destination" or not isinstance(district, str):
            continue
        normalized_district = district.strip().lower()
        if not normalized_district or normalized_district in seen_districts:
            continue

        selected.append(match)
        selected_keys.add((match.source, match.source_id))
        seen_districts.add(normalized_district)

        if len(selected) >= limit:
            return selected

    for match in matches:
        key = (match.source, match.source_id)
        if key in selected_keys:
            continue
        selected.append(match)
        if len(selected) >= limit:
            break

    return selected


def _join_text(*values: Any) -> str:
    return " ".join(str(value) for value in values if value not in (None, ""))


def _compact_dict(values: dict[str, Any]) -> dict[str, Any]:
    return {
        key: value
        for key, value in values.items()
        if value not in (None, "", [], {})
    }


def _flag_text(label: str, enabled: bool | None) -> str | None:
    return label if enabled else None


def _money(value: Decimal | int | float | None) -> str | None:
    if value is None:
        return None

    return f"{Decimal(value):.2f}"
