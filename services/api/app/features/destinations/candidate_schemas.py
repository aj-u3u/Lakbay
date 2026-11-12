from datetime import datetime, timezone
from decimal import Decimal
from typing import Literal
from urllib.parse import urlsplit

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


CandidateStatus = Literal["staged", "rejected", "published"]
AccessPolicy = Literal["public", "customers", "permit"]


class CandidateCreate(BaseModel):
    osm_type: Literal["node", "way", "relation"]
    osm_id: int = Field(gt=0)
    osm_url: str = Field(max_length=2048)
    source_area: str = Field(min_length=2, max_length=100)
    source_tag: str = Field(min_length=3, max_length=255)
    name: str = Field(min_length=2, max_length=255)
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    suggested_category: str | None = Field(default=None, max_length=500)

    @model_validator(mode="after")
    def validate_osm_identity(self) -> "CandidateCreate":
        expected = f"https://www.openstreetmap.org/{self.osm_type}/{self.osm_id}"
        if self.osm_url != expected:
            raise ValueError("osm_url must match the OSM type and ID")
        return self


class CandidateUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=255)
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
    category: str | None = Field(default=None, max_length=500)
    visitor_purpose: str | None = None
    description: str | None = None
    district: str | None = Field(default=None, max_length=255)
    location: str | None = Field(default=None, max_length=500)
    vibes: str | None = Field(default=None, max_length=500)
    activities: str | None = None
    estimated_cost: Decimal | None = Field(default=None, ge=0, max_digits=10, decimal_places=2)
    entrance_fee: str | None = Field(default=None, max_length=255)
    overnight_fee: str | None = Field(default=None, max_length=255)
    operating_hours: str | None = Field(default=None, max_length=255)
    access_policy: AccessPolicy | None = None
    access_source_url: str | None = Field(default=None, max_length=2048)
    access_verified_at: datetime | None = None
    review_notes: str | None = None

    @field_validator("access_source_url")
    @classmethod
    def validate_source_url(cls, value: str | None) -> str | None:
        if value is None:
            return None
        parsed = urlsplit(value)
        if parsed.scheme not in {"http", "https"} or not parsed.netloc:
            raise ValueError("access_source_url must be an HTTP or HTTPS URL")
        return value

    @field_validator("access_verified_at")
    @classmethod
    def validate_verification_time(cls, value: datetime | None) -> datetime | None:
        if value is not None and value.tzinfo is None:
            raise ValueError("access_verified_at must include a timezone")
        return value.astimezone(timezone.utc) if value is not None else None


class CandidateReject(BaseModel):
    reason: str = Field(min_length=5)


class CandidateResponse(BaseModel):
    candidate_id: int
    osm_type: str
    osm_id: int
    osm_url: str
    source_area: str
    source_tag: str
    name: str
    lat: float
    lng: float
    suggested_category: str | None
    category: str | None
    visitor_purpose: str | None
    description: str | None
    district: str | None
    location: str | None
    vibes: str | None
    activities: str | None
    estimated_cost: Decimal | None
    entrance_fee: str | None
    overnight_fee: str | None
    operating_hours: str | None
    access_policy: str | None
    access_source_url: str | None
    access_verified_at: datetime | None
    review_status: CandidateStatus
    review_notes: str | None
    destination_id: int | None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
