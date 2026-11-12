from typing import Annotated

from fastapi import APIRouter, Depends, File, UploadFile
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.users.models import User
from app.features.users.schemas import UserResponse, UserUpdateRequest
from app.features.users.service import UserService
from app.integrations.storage.client import CloudinaryStorageClient, get_storage_client


router = APIRouter(prefix="/users", tags=["users"])


@router.get("/me", response_model=UserResponse, summary="Get current user")
async def get_me(
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> UserResponse:
    return await UserService(session).get_me(current_user)


@router.patch("/me", response_model=UserResponse, summary="Update current user")
async def update_me(
    data: UserUpdateRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> UserResponse:
    return await UserService(session).update_me(user=current_user, data=data)


@router.post(
    "/me/avatar",
    response_model=UserResponse,
    summary="Upload current user's profile photo",
    description=(
        "Uploads one validated image to Cloudinary and saves its secure URL to "
        "the current user's profile."
    ),
)
async def upload_my_avatar(
    file: Annotated[UploadFile, File(...)],
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    storage_client: Annotated[CloudinaryStorageClient, Depends(get_storage_client)],
) -> UserResponse:
    return await UserService(session, storage_client=storage_client).upload_avatar(
        user=current_user,
        file=file,
    )
