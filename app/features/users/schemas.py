from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class UserResponse(BaseModel):
    user_id: int
    full_name: str
    email: EmailStr
    role: str
    avatar_url: str | None
    is_active: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class UserUpdateRequest(BaseModel):
    full_name: str | None = Field(default=None, min_length=2, max_length=255)
    avatar_url: str | None = Field(default=None, max_length=2048)


class AdminUserItem(BaseModel):
    user_id: int
    full_name: str
    email: EmailStr
    role: str
    is_active: bool
    has_active_session: bool


class AdminUserDirectoryResponse(BaseModel):
    total_users: int
    signed_in_users: int
    matching_users: int
    items: list[AdminUserItem]
