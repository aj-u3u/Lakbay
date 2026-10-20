import hashlib
import math
import re
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.accommodations.models import Accommodation
from app.features.ai.retrieval_intent import DISTRICTS, resolve_retrieval_intent
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
        self.coverage: dict[str, Any] = {}

    async def retrieve(
        self,
        query: str,
        *,
        limit: int = 6,
        history: list[str] | None = None,
        context: dict | None = None,
    ) -> list[RagMatch]:
        self.coverage = {"status": "disabled", "destinations": [], "truncated": False}
        if limit <= 0:
            return []

        query_terms = _terms(query)
        if not query_terms:
            self.coverage["status"] = "no_query"
            return []

        documents = list(
            {
                (doc.source, doc.source_id): doc
                for doc in await self._load_documents()
            }.values()
        )
        destinations = [doc for doc in documents if doc.source == "destination"]
        intent = resolve_retrieval_intent(
            query,
            history=history,
            context=context,
            locations=[
                value
                for doc in destinations
                for key in ("district", "location", "name")
                if isinstance(value := doc.payload.get(key), str)
            ],
        )
        self.coverage.update(
            status="no_matches",
            requested_locations=list(intent.target_locations),
            interest=intent.interest,
            origin=intent.origin,
        )
        if intent.needs_clarification:
            self.coverage["status"] = "needs_clarification"
            return []

        # Older turns supply omitted filters, not competing geographic keywords.
        ranking_query = " ".join(
            [query, *intent.target_locations, intent.interest or ""]
        )
        query_terms = _terms(ranking_query)
        query_vector = _embed_terms(query_terms)
        named_rate_destinations = {
            doc.payload["destination_id"]
            for doc in documents
            if doc.source != "destination"
            and isinstance(name := doc.payload.get("name"), str)
            and len(TOKEN_PATTERN.findall(name)) >= 2
            and _contains_place(query, name)
        }
        candidates = [
            doc
            for doc in destinations
            if all(_destination_in_place(doc, place) for place in intent.target_locations)
            and _matches_interest(doc, intent.interest)
            and (
                not named_rate_destinations
                or doc.source_id in named_rate_destinations
            )
        ]
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
            for document in candidates
        ]

        matches = [
            match
            for match in matches
            if match.score >= MIN_RAG_SCORE
            or match.source_id in named_rate_destinations
        ]
        matches.sort(key=lambda match: (-match.score, match.source_id))

        if intent.region_wide and not intent.target_locations:
            matches = _diversify_by_district(matches, limit=len(matches))
        if not matches:
            return []

        # Reserve space for linked rates; rates never displace their destination.
        selected = matches[:max(1, limit // 3)]
        result = list(selected)
        selected_ids = {match.source_id for match in selected}
        rate_matches: dict[tuple[int, str], list[RagMatch]] = {}
        for document in documents:
            if document.source == "destination":
                continue
            rate_match = RagMatch(
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
            key = (document.payload["destination_id"], document.source)
            rate_matches.setdefault(key, []).append(rate_match)
        for rates in rate_matches.values():
            rates.sort(
                key=lambda match: (
                    -int(
                        match.source == "transportation"
                        and bool(intent.origin)
                        and _contains_place(
                            match.payload.get("route_from", ""), intent.origin
                        )
                    ),
                    -match.score,
                    match.source_id,
                )
            )

        source_order = ("accommodation", "transportation")
        if set(TOKEN_PATTERN.findall(query.lower())).intersection(
            {
                "transport", "transportation", "commute", "fare", "fares",
                "ferry", "bus", "boat", "route",
            }
        ):
            source_order = tuple(reversed(source_order))

        def add_linked_rates(destination_id: int) -> None:
            for source in source_order:
                rates = rate_matches.get((destination_id, source), [])
                if rates and len(result) < limit:
                    result.append(rates[0])

        for destination in selected:
            add_linked_rates(destination.source_id)
        for destination in matches[len(selected):]:
            if len(result) >= limit:
                break
            result.append(destination)
            selected_ids.add(destination.source_id)
            add_linked_rates(destination.source_id)

        included_keys = {(match.source, match.source_id) for match in result}
        for key, rates in rate_matches.items():
            if key[0] not in selected_ids:
                continue
            for rate in rates:
                if len(result) >= limit:
                    break
                if (rate.source, rate.source_id) not in included_keys:
                    result.append(rate)
                    included_keys.add((rate.source, rate.source_id))

        included_rates = {
            (match.payload["destination_id"], match.source)
            for match in result
            if match.source != "destination"
        }
        self.coverage.update(
            status="matched",
            destinations=[
                {
                    "destination_id": destination.source_id,
                    **{
                        f"{source}_status": (
                            "included"
                            if (destination.source_id, source) in included_rates
                            else "omitted_by_limit"
                            if rate_matches.get((destination.source_id, source))
                            else "no_available_records"
                        )
                        for source in ("accommodation", "transportation")
                    },
                }
                for destination in result
                if destination.source == "destination"
            ],
            truncated=(
                len(selected_ids) < len(matches)
                or any(
                    (rate.source, rate.source_id) not in included_keys
                    for key, rates in rate_matches.items()
                    if key[0] in selected_ids
                    for rate in rates
                )
            ),
        )
        return result

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
        if token == "beaches":
            token = "beach"
        terms.append(token)
        terms.extend(sorted(SYNONYMS.get(token, set())))

        if token.endswith("ies") and len(token) > 4:
            terms.append(f"{token[:-3]}y")
        elif token.endswith("ing") and len(token) > 5:
            terms.append(token[:-3])
        elif token.endswith("s") and len(token) > 3:
            terms.append(token[:-1])

    return terms


def _contains_place(text: str, place: str) -> bool:
    words = " ".join(TOKEN_PATTERN.findall(text.lower()))
    location = " ".join(TOKEN_PATTERN.findall(place.lower()))
    return bool(location) and f" {location} " in f" {words} "


def _destination_in_place(document: RagDocument, place: str) -> bool:
    # Travel directions and rate origins are not destination geography.
    keys = (
        ("district", "location")
        if place in DISTRICTS
        else ("district", "location", "name")
    )
    return any(
        _contains_place(str(document.payload.get(key) or ""), place)
        for key in keys
    )


def _matches_interest(document: RagDocument, interest: str | None) -> bool:
    if interest is None:
        return True
    words = set(
        TOKEN_PATTERN.findall(
            _join_text(
                *(document.payload.get(key) for key in ("category", "vibes", "activities"))
            ).lower()
        )
    )
    evidence = {
        "beach": {"beach", "beaches", "coast", "coastal", "seaside"},
        "mountain": {"mountain", "mountains", "hike", "hiking", "trail", "trekking"},
        "waterfall": {"waterfall", "waterfalls", "falls"},
        "food": {"food", "restaurant", "restaurants", "cafe", "cafes", "dining"},
    }
    return bool(words.intersection(evidence.get(interest, {interest})))


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
