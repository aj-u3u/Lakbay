from typing import Annotated

from fastapi import Depends, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.core.security import ExpiredTokenError, InvalidTokenError, decode_jwt_token
from app.db.session import get_db_session
from app.features.users.models import User
from app.features.users.repository import UserRepository


bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(bearer_scheme),
    ],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> User:
    if credentials is None:
        raise LakbayAPIError(
            "Authentication credentials were not provided.",
            code="not_authenticated",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    try:
        payload = decode_jwt_token(credentials.credentials)
    except ExpiredTokenError as exc:
        raise LakbayAPIError(
            "Authentication token has expired.",
            code="token_expired",
            status_code=status.HTTP_401_UNAUTHORIZED,
        ) from exc
    except InvalidTokenError as exc:
        raise LakbayAPIError(
            "Authentication token is invalid.",
            code="invalid_token",
            status_code=status.HTTP_401_UNAUTHORIZED,
        ) from exc

    if payload.get("type") != "access":
        raise LakbayAPIError(
            "Authentication token type is invalid.",
            code="invalid_token_type",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    user_id = payload.get("sub")

    try:
        parsed_user_id = int(user_id)
    except (TypeError, ValueError) as exc:
        raise LakbayAPIError(
            "Authentication token subject is invalid.",
            code="invalid_token_subject",
            status_code=status.HTTP_401_UNAUTHORIZED,
        ) from exc

    user = await UserRepository(session).get_by_id(parsed_user_id)

    if user is None or not user.is_active:
        raise LakbayAPIError(
            "Authenticated user was not found.",
            code="user_not_found",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    return user


async def require_admin(
    current_user: Annotated[User, Depends(get_current_user)],
) -> User:
    if current_user.role != "admin":
        raise LakbayAPIError(
            "Admin access is required.",
            code="admin_required",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    return current_user
