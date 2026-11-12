from fastapi import UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import LakbayAPIError
from app.features.users.models import User
from app.features.users.repository import UserRepository
from app.features.users.schemas import (
    AdminUserDirectoryResponse,
    AdminUserItem,
    UserResponse,
    UserUpdateRequest,
)
from app.integrations.storage.client import CloudinaryStorageClient
from app.integrations.storage.uploads import (
    read_validated_image,
    reserve_cloudinary_upload,
)


class UserService:
    def __init__(
        self,
        session: AsyncSession,
        *,
        storage_client: CloudinaryStorageClient | None = None,
        settings: Settings | None = None,
    ) -> None:
        self.session = session
        self.users = UserRepository(session)
        self.storage_client = storage_client
        self.settings = settings or get_settings()

    async def admin_directory(
        self, *, search: str | None, limit: int, offset: int
    ) -> AdminUserDirectoryResponse:
        total, signed_in, matching, users, active_ids = await self.users.admin_directory(
            search=search, limit=limit, offset=offset
        )
        return AdminUserDirectoryResponse(
            total_users=total,
            signed_in_users=signed_in,
            matching_users=matching,
            items=[
                AdminUserItem(
                    user_id=user.user_id,
                    full_name=user.full_name,
                    email=user.email,
                    role=user.role,
                    is_active=user.is_active,
                    has_active_session=user.is_active and user.user_id in active_ids,
                )
                for user in users
            ],
        )

    async def get_me(self, user: User) -> UserResponse:
        return UserResponse.model_validate(user)

    async def update_me(
        self,
        *,
        user: User,
        data: UserUpdateRequest,
    ) -> UserResponse:
        update_data = data.model_dump(exclude_unset=True)

        if not update_data:
            raise LakbayAPIError(
                "At least one profile field must be provided.",
                code="empty_profile_update",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        updated_user = await self.users.update_profile(
            user=user,
            full_name=update_data.get("full_name"),
            avatar_url=update_data.get("avatar_url"),
        )
        await self.session.commit()
        await self.session.refresh(updated_user)

        return UserResponse.model_validate(updated_user)

    async def upload_avatar(self, *, user: User, file: UploadFile) -> UserResponse:
        file_bytes = await read_validated_image(file, self.settings)
        reserve_cloudinary_upload(user_id=user.user_id, settings=self.settings)

        storage = self.storage_client or CloudinaryStorageClient(self.settings)
        result = await storage.upload_image(
            file_bytes=file_bytes,
            filename=file.filename,
            content_type=(file.content_type or "").lower(),
            folder_suffix=f"users/{user.user_id}/profile",
        )

        updated_user = await self.users.update_profile(user=user, avatar_url=result.image_url)
        await self.session.commit()
        await self.session.refresh(updated_user)
        return UserResponse.model_validate(updated_user)
