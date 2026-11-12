from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import require_admin
from app.db.session import get_db_session
from app.features.users.models import User
from app.features.users.schemas import AdminUserDirectoryResponse
from app.features.users.service import UserService


router = APIRouter(prefix="/admin/users", tags=["admin users"])


@router.get("", response_model=AdminUserDirectoryResponse)
async def list_admin_users(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    _admin: Annotated[User, Depends(require_admin)],
    search: str | None = Query(default=None, max_length=255),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> AdminUserDirectoryResponse:
    return await UserService(session).admin_directory(
        search=search, limit=limit, offset=offset
    )
