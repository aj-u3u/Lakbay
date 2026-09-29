from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


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
    estimated_cost: Decimal = Field(
        default=Decimal("0.00"),
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


class DestinationResponse(DestinationBase):
    destination_id: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


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
