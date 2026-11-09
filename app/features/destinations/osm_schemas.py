"""Admin-only OSM match and field suggestion responses."""

from pydantic import BaseModel, Field


class OSMMatch(BaseModel):
    osm_type: str
    osm_id: int
    osm_url: str
    name: str
    lat: float
    lng: float
    category: str | None = None
    source_tag: str | None = None
    existing_candidate_id: int | None = None
    existing_candidate_status: str | None = None
    existing_destination_id: int | None = None


class OSMSuggestion(BaseModel):
    field: str
    value: str | float
    source_tag: str
    source_url: str
    current_value: str | float | None = None


class OSMSuggestionResponse(BaseModel):
    osm_type: str
    osm_id: int
    osm_url: str
    candidate_id: int | None = None
    suggestions: list[OSMSuggestion] = Field(default_factory=list)
    website: str | None = None
    fee_hint: str | None = None
    # Raw OSM tag such as "leisure=garden". Only tags that match a catalog category
    # word also appear as a `category` suggestion.
    category_hint: str | None = None
    note: str = "Suggestions are unverified. Review each field before saving; the OSM center is not a visitor entrance."
