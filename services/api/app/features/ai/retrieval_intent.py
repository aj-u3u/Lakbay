"""Resolve conservative retrieval constraints without another model call."""

import re
from dataclasses import dataclass


DISTRICTS = (
    "davao city", "davao del norte", "davao del sur", "davao oriental",
    "davao occidental", "davao de oro",
)
CITY_DISTRICTS = {
    "samal": "davao del norte", "tagum": "davao del norte",
    "panabo": "davao del norte", "mati": "davao oriental",
    "digos": "davao del sur",
}
GENERIC_PLACES = {
    "area", "beach", "beaches", "city", "coast", "destination", "destinations",
    "hotel", "island", "mountain", "mountains", "place", "places", "province",
    "region", "resort", "restaurant", "travel", "trip", "waterfall", "waterfalls",
    "davao",
}
INTERESTS = {
    "beach": r"\b(?:beach(?:es)?|coastal|coast)\b",
    "mountain": r"\b(?:mountains?|hikes?|hiking)\b",
    "waterfall": r"\b(?:waterfalls?|falls)\b",
    "food": r"\b(?:food|restaurants?|cafes?)\b",
}
ORIGIN_PATTERN = re.compile(
    r"\b(?:from|starting(?: out)? in|start in|departure(?: from| location)?|"
    r"departing from|leaving from)\s+(?:is\s+)?(.+?)"
    r"(?=\s+\b(?:to|for|with|within|and|but|then|want|visit|budget)\b|$)"
)
REGION_PATTERN = re.compile(r"\b(?:davao region|region xi)\b")
TARGET_KEYS = (
    "target_locations", "target_location", "destination", "destinations",
    "destination_name", "preferred_districts", "district", "province", "city",
    "location",
)
ORIGIN_KEYS = ("origin", "starting_point", "start_location", "departure_location", "route_from")
INTEREST_KEYS = ("interest", "interests", "category", "categories", "preferred_categories")


@dataclass(frozen=True)
class RetrievalIntent:
    target_locations: tuple[str, ...] = ()
    origin: str | None = None
    interest: str | None = None
    region_wide: bool = False
    needs_clarification: bool = False

    def to_dict(self) -> dict:
        return {
            "target_locations": list(self.target_locations),
            "origin": self.origin,
            "interest": self.interest,
            "region_wide": self.region_wide,
            "needs_clarification": self.needs_clarification,
        }


def resolve_retrieval_intent(
    message: str,
    *,
    history: list[str] | None = None,
    context: dict | None = None,
    locations: list[str] | None = None,
) -> RetrievalIntent:
    """Latest explicit fields win, followed by user history, then context.

    Locations are normalized whole phrases. Unknown explicit targets are kept so
    the retriever cannot silently search everywhere instead.
    """
    aliases = _location_aliases(locations or [])
    current = _parse_message(message, aliases)
    candidates = [(current, _has_interest(message))]
    candidates.extend(
        (_parse_message(item, aliases), _has_interest(item))
        for item in reversed(history or [])
    )
    candidates.append((
        _parse_context(context or {}, aliases),
        _has_interest(" ".join(_values(context or {}, INTEREST_KEYS))),
    ))

    target = next((item for item, _ in candidates if item.target_locations or item.region_wide), current)
    origin = next((item.origin for item, _ in candidates if item.origin), None)
    interest = next((item.interest for item, explicit in candidates if explicit), None)
    return RetrievalIntent(
        target_locations=target.target_locations,
        origin=origin,
        interest=interest,
        region_wide=target.region_wide,
        needs_clarification=target.needs_clarification or current.needs_clarification,
    )


def _normalize(value: str) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", value.lower()))


def _location_aliases(locations: list[str]) -> dict[str, str]:
    aliases = {value: value for value in DISTRICTS}
    aliases.update({value: value for value in CITY_DISTRICTS})
    aliases["island garden city of samal"] = "samal"
    for value in locations:
        if not isinstance(value, str):
            continue
        normalized = _normalize(value)
        if not normalized or normalized in GENERIC_PLACES:
            continue
        for part in re.split(r"[,;/]", value):
            place = _normalize(part)
            city = re.sub(r"^(?:island garden )?city of |^municipality of ", "", place)
            city = re.sub(r" (?:city|municipality)$", "", city)
            if city and city not in GENERIC_PLACES:
                aliases.setdefault(place, aliases.get(city, city))
                if city != place:
                    aliases.setdefault(city, city)
        aliases.setdefault(normalized, normalized)
    return aliases


def _find_places(text: str, aliases: dict[str, str]) -> tuple[str, ...]:
    found: list[str] = []
    occupied: list[tuple[int, int]] = []
    for alias in sorted(aliases, key=len, reverse=True):
        for match in re.finditer(r"\b" + re.escape(alias) + r"\b", text):
            if any(match.start() < end and match.end() > start for start, end in occupied):
                continue
            occupied.append(match.span())
            if aliases[alias] not in found:
                found.append(aliases[alias])
    # A city and its province identify one target, not contradictory targets.
    provinces = {
        district for place in found for city, district in CITY_DISTRICTS.items()
        if re.search(r"\b" + re.escape(city) + r"\b", place)
    }
    return tuple(place for place in found if place not in provinces)


def _interest(text: str) -> tuple[str | None, bool]:
    found = [key for key, pattern in INTERESTS.items() if re.search(pattern, text)]
    return (found[0] if len(found) == 1 else None, len(found) > 1)


def _has_interest(text: str) -> bool:
    return any(re.search(pattern, _normalize(text)) for pattern in INTERESTS.values())


def _parse_message(message: str, aliases: dict[str, str]) -> RetrievalIntent:
    text = _normalize(message)
    target_text = text
    origin = None
    for match in ORIGIN_PATTERN.finditer(text):
        raw_origin = match.group(1).strip()
        matches = _find_places(raw_origin, aliases)
        origin = matches[0] if len(matches) == 1 else raw_origin
        target_text = target_text[:match.start()] + " " * (match.end() - match.start()) + target_text[match.end():]

    targets = _find_places(target_text, aliases)
    region_wide = bool(REGION_PATTERN.search(target_text))
    interest, _ = _interest(target_text)
    clarification = len(targets) > 1
    if region_wide:
        # Whole-region requests reset specific locations from previous turns.
        targets = ()
    elif not targets:
        unknown = _unknown_target(target_text)
        if unknown:
            targets = (unknown,)
            clarification = True
    return RetrievalIntent(targets, origin, interest, region_wide, clarification)


def _unknown_target(text: str) -> str | None:
    matches = re.finditer(
        r"\b(?:in|to|visit|visiting|actually|instead)\s+(.+?)"
        r"(?=\s+\b(?:with|within|for|on|budget|and|but|please|that|during)\b|$)",
        text,
    )
    for match in matches:
        candidate = re.sub(r"^(?:the|province of|city of)\s+", "", match.group(1)).strip()
        words = candidate.split()
        if not words or any(word.isdigit() for word in words):
            continue
        if words[0] in {"a", "an", "my", "travel", "go", "stay", "spend", "see", "explore"}:
            continue
        if candidate == "davao":
            return candidate
        if all(word in GENERIC_PLACES or word in {"the", "relax", "relaxing", "solo"} for word in words):
            continue
        return candidate
    return None


def _values(context: dict, keys: tuple[str, ...]) -> list[str]:
    values: list[str] = []
    for key in keys:
        value = context.get(key)
        if isinstance(value, str):
            values.append(value)
        elif isinstance(value, list):
            values.extend(item for item in value if isinstance(item, str))
    return values


def _parse_context(context: dict, aliases: dict[str, str]) -> RetrievalIntent:
    targets: list[str] = []
    region_wide = False
    for value in _values(context, TARGET_KEYS):
        normalized = _normalize(value)
        if REGION_PATTERN.search(normalized):
            region_wide = True
            continue
        places = _find_places(normalized, aliases)
        targets.extend(places or ([normalized] if normalized else []))
    targets = list(dict.fromkeys(targets))
    provinces = {CITY_DISTRICTS[place] for place in targets if place in CITY_DISTRICTS}
    targets = [place for place in targets if place not in provinces]
    origins = _values(context, ORIGIN_KEYS)
    origin = None
    if origins:
        normalized = _normalize(origins[0])
        places = _find_places(normalized, aliases)
        origin = places[0] if len(places) == 1 else normalized
    interest, _ = _interest(" ".join(_values(context, INTEREST_KEYS)).lower())
    return RetrievalIntent(
        tuple(targets) if not region_wide else (), origin, interest, region_wide,
        len(targets) > 1,
    )
