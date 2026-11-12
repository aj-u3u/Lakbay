from datetime import datetime
from decimal import Decimal
from urllib.parse import urlsplit

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


class DestinationBase(BaseModel):
    name: str = Field(min_length=2, max_length=255)
    description: str | None = None
    district: str | None = Field(default=None, max_length=255)
    location: str | None = Field(default=None, max_length=500)
    category: str | None = Field(default=None, max_length=500)
    vibes: str | None = Field(default=None, max_length=500)
    activities: str | None = None
    lat: float = Field(ge=-90, le=90)
    lng: float = Field(ge=-180, le=180)
    arrival_lat: float | None = Field(default=None, ge=-90, le=90)
    arrival_lng: float | None = Field(default=None, ge=-180, le=180)
    arrival_source_url: str | None = Field(default=None, max_length=2048)
    arrival_verified_at: datetime | None = None
    route_ready: bool = False
    estimated_cost: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=10,
        decimal_places=2,
    )
    entrance_fee: str | None = Field(default=None, max_length=255)
    overnight_fee: str | None = Field(default=None, max_length=255)
    operating_hours: str | None = Field(default=None, max_length=255)
    best_time_to_visit: str | None = None
    how_to_get_there: str | None = None
    estimated_travel_time: str | None = None
    travel_notes: str | None = None
    what_to_bring: str | None = None
    is_kid_friendly: bool = False
    is_wheelchair_accessible: bool = False
    is_pet_friendly: bool = False
    is_elderly_friendly: bool = False
    family_friendly: bool = False
    couple_friendly: bool = False
    group_friendly: bool = False
    budget_class: str | None = Field(default=None, max_length=50)
    crowd_level: str | None = Field(default=None, max_length=50)
    difficulty_level: str | None = Field(default=None, max_length=50)
    stay_duration_type: str | None = Field(default=None, max_length=50)
    transport_accessibility: str | None = Field(default=None, max_length=100)
    image_url: str | None = Field(default=None, max_length=2048)

    @field_validator("arrival_source_url")
    @classmethod
    def validate_arrival_source_url(cls, value: str | None) -> str | None:
        return _validate_arrival_source_url(value)

    @model_validator(mode="after")
    def validate_arrival_point(self) -> "DestinationBase":
        if (self.arrival_lat is None) != (self.arrival_lng is None):
            raise ValueError("arrival_lat and arrival_lng must be provided together")
        if self.route_ready and (
            self.arrival_lat is None
            or not self.arrival_source_url
            or self.arrival_verified_at is None
        ):
            raise ValueError(
                "route_ready requires arrival coordinates, source URL, and verification time"
            )
        return self


class DestinationCreate(DestinationBase):
    pass


class DestinationUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=255)
    description: str | None = None
    district: str | None = Field(default=None, max_length=255)
    location: str | None = Field(default=None, max_length=500)
    category: str | None = Field(default=None, max_length=500)
    vibes: str | None = Field(default=None, max_length=500)
    activities: str | None = None
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)
    arrival_lat: float | None = Field(default=None, ge=-90, le=90)
    arrival_lng: float | None = Field(default=None, ge=-180, le=180)
    arrival_source_url: str | None = Field(default=None, max_length=2048)
    arrival_verified_at: datetime | None = None
    route_ready: bool | None = None
    estimated_cost: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=10,
        decimal_places=2,
    )
    entrance_fee: str | None = Field(default=None, max_length=255)
    overnight_fee: str | None = Field(default=None, max_length=255)
    operating_hours: str | None = Field(default=None, max_length=255)
    best_time_to_visit: str | None = None
    how_to_get_there: str | None = None
    estimated_travel_time: str | None = None
    travel_notes: str | None = None
    what_to_bring: str | None = None
    is_kid_friendly: bool | None = None
    is_wheelchair_accessible: bool | None = None
    is_pet_friendly: bool | None = None
    is_elderly_friendly: bool | None = None
    family_friendly: bool | None = None
    couple_friendly: bool | None = None
    group_friendly: bool | None = None
    budget_class: str | None = Field(default=None, max_length=50)
    crowd_level: str | None = Field(default=None, max_length=50)
    difficulty_level: str | None = Field(default=None, max_length=50)
    stay_duration_type: str | None = Field(default=None, max_length=50)
    transport_accessibility: str | None = Field(default=None, max_length=100)
    image_url: str | None = Field(default=None, max_length=2048)
    is_active: bool | None = None

    @field_validator("arrival_source_url")
    @classmethod
    def validate_arrival_source_url(cls, value: str | None) -> str | None:
        return _validate_arrival_source_url(value)


class DestinationResponse(DestinationBase):
    destination_id: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


def _validate_arrival_source_url(value: str | None) -> str | None:
    if value is None:
        return None
    parsed = urlsplit(value)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("arrival_source_url must be an HTTP or HTTPS URL")
    return value


class DestinationListQuery(BaseModel):
    search: str | None = None
    district: str | None = None
    category: str | None = None
    budget_class: str | None = None
    difficulty_level: str | None = None
    kid_friendly: bool | None = None
    wheelchair_accessible: bool | None = None
    pet_friendly: bool | None = None
    family_friendly: bool | None = None
    couple_friendly: bool | None = None
    group_friendly: bool | None = None
    limit: int = Field(default=50, ge=1, le=100)
    offset: int = Field(default=0, ge=0)
    include_inactive: bool = False
