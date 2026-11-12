from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.auth.schemas import (
    AdminRegisterRequest,
    AuthResponse,
    LoginRequest,
    LogoutRequest,
    MessageResponse,
    RefreshRequest,
    RegisterRequest,
)
from app.features.auth.service import AuthService
from app.features.users.models import User


router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register a traveler account",
)
async def register(
    data: RegisterRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> AuthResponse:
    return await AuthService(session).register_user(data)


@router.post(
    "/register/admin",
    response_model=AuthResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Register an admin account",
)
async def register_admin(
    data: AdminRegisterRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> AuthResponse:
    return await AuthService(session).register_admin(data)


@router.post(
    "/login",
    response_model=AuthResponse,
    summary="Log in with email and password",
)
async def login(
    data: LoginRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> AuthResponse:
    return await AuthService(session).login(data)


@router.post(
    "/refresh",
    response_model=AuthResponse,
    summary="Rotate refresh token and issue a new access token",
)
async def refresh(
    data: RefreshRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> AuthResponse:
    return await AuthService(session).refresh(data)


@router.post(
    "/logout",
    response_model=MessageResponse,
    summary="Log out by revoking a refresh token",
)
async def logout(
    data: LogoutRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> MessageResponse:
    await AuthService(session).logout(
        refresh_token=data.refresh_token,
        user=current_user,
    )

    return MessageResponse(message="Logged out successfully.")
