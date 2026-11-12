from datetime import datetime
from typing import Literal

from pydantic import BaseModel, EmailStr, Field, field_validator


TripMemoryStatus = Literal["active", "deleted"]


class TripMemoryUploadResponse(BaseModel):
    image_url: str
    cloudinary_public_id: str | None
    original_filename: str | None
    content_type: str
    bytes: int
    width: int | None = None
    height: int | None = None
    format: str | None = None
    resource_type: str | None = None


class TripMemoryCreate(BaseModel):
    image_url: str = Field(min_length=1, max_length=2000)
    cloudinary_public_id: str | None = Field(default=None, max_length=500)
    destination_id: int | None = Field(default=None, ge=1)
    caption: str | None = Field(default=None, max_length=500)
    location_tag: str | None = Field(default=None, max_length=255)
    taken_at: datetime | None = None

    @field_validator("image_url")
    @classmethod
    def validate_image_url(cls, value: str) -> str:
        if not value.startswith(("http://", "https://")):
            raise ValueError("image_url must be an HTTP or HTTPS URL")

        return value


class TripMemoryUpdate(BaseModel):
    destination_id: int | None = Field(default=None, ge=1)
    caption: str | None = Field(default=None, max_length=500)
    location_tag: str | None = Field(default=None, max_length=255)
    taken_at: datetime | None = None


class TripMemoryResponse(BaseModel):
    trip_memory_id: int
    trip_id: int
    uploaded_by_user_id: int
    uploaded_by_trip_member_id: int
    uploaded_by_full_name: str
    uploaded_by_email: EmailStr
    destination_id: int | None
    destination_name: str | None
    image_url: str
    cloudinary_public_id: str | None
    caption: str | None
    location_tag: str | None
    taken_at: datetime | None
    status: TripMemoryStatus
    like_count: int
    comment_count: int
    created_at: datetime
    updated_at: datetime
