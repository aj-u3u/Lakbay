from datetime import datetime
from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field


class TransportationCreate(BaseModel):
    vehicle_type: str = Field(min_length=2, max_length=100)
    transport_mode: str = Field(min_length=2, max_length=100)
    route_from: str = Field(min_length=2, max_length=255)
    route_to: str = Field(min_length=2, max_length=255)
    price: Decimal = Field(ge=0, max_digits=10, decimal_places=2)
    currency: Literal["PHP"] = "PHP"
    charging_unit: Literal["per_person", "per_vehicle", "per_group"] | None = None
    duration_minutes: int | None = Field(default=None, ge=0)
    duration_text: str | None = Field(default=None, max_length=100)
    notes: str | None = None
    is_available: bool = True


class TransportationUpdate(BaseModel):
    vehicle_type: str | None = Field(default=None, min_length=2, max_length=100)
    transport_mode: str | None = Field(default=None, min_length=2, max_length=100)
    route_from: str | None = Field(default=None, min_length=2, max_length=255)
    route_to: str | None = Field(default=None, min_length=2, max_length=255)
    price: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=10,
        decimal_places=2,
    )
    currency: Literal["PHP"] | None = None
    charging_unit: Literal["per_person", "per_vehicle", "per_group"] | None = None
    duration_minutes: int | None = Field(default=None, ge=0)
    duration_text: str | None = Field(default=None, max_length=100)
    notes: str | None = None
    is_available: bool | None = None


class TransportationResponse(BaseModel):
    transportation_id: int
    destination_id: int
    vehicle_type: str
    transport_mode: str
    route_from: str
    route_to: str
    price: Decimal
    currency: str
    charging_unit: str | None
    duration_minutes: int | None
    duration_text: str | None
    notes: str | None
    is_available: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
