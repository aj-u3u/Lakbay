from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field


class AccommodationCreate(BaseModel):
    name: str = Field(min_length=2, max_length=255)
    room_type: str = Field(min_length=2, max_length=255)
    price: Decimal = Field(ge=0, max_digits=10, decimal_places=2)
    capacity: int = Field(default=2, ge=1)
    description: str | None = None
    is_available: bool = True


class AccommodationUpdate(BaseModel):
    name: str | None = Field(default=None, min_length=2, max_length=255)
    room_type: str | None = Field(default=None, min_length=2, max_length=255)
    price: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=10,
        decimal_places=2,
    )
    capacity: int | None = Field(default=None, ge=1)
    description: str | None = None
    is_available: bool | None = None


class AccommodationResponse(BaseModel):
    accommodation_id: int
    destination_id: int
    name: str
    room_type: str
    price: Decimal
    capacity: int
    description: str | None
    is_available: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
