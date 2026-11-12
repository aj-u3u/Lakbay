from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import require_admin
from app.db.session import get_db_session
from app.features.accommodations.schemas import (
    AccommodationCreate,
    AccommodationResponse,
    AccommodationUpdate,
)
from app.features.accommodations.service import AccommodationService
from app.features.users.models import User


destination_router = APIRouter(
    prefix="/destinations/{destination_id}/accommodations",
    tags=["accommodations"],
)
router = APIRouter(prefix="/accommodations", tags=["accommodations"])


@destination_router.get(
    "",
    response_model=list[AccommodationResponse],
    summary="List destination accommodations",
    description=(
        "Returns available accommodation options for one active destination. "
        "Use this when Flutter needs the stay choices and estimated room costs "
        "shown under a destination."
    ),
)
async def list_destination_accommodations(
    destination_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> list[AccommodationResponse]:
    return await AccommodationService(session).list_for_destination(
        destination_id,
    )


@destination_router.post(
    "",
    response_model=AccommodationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create destination accommodation",
    description=(
        "Admin-only endpoint for adding a room, homestay, cottage, or similar "
        "stay option under an existing active destination."
    ),
)
async def create_destination_accommodation(
    destination_id: int,
    data: AccommodationCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> AccommodationResponse:
    return await AccommodationService(session).create_accommodation(
        destination_id,
        data,
    )


@router.patch(
    "/{accommodation_id}",
    response_model=AccommodationResponse,
    summary="Update accommodation",
    description=(
        "Admin-only endpoint for changing accommodation details such as name, "
        "room type, price, capacity, notes, or availability."
    ),
)
async def update_accommodation(
    accommodation_id: int,
    data: AccommodationUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> AccommodationResponse:
    return await AccommodationService(session).update_accommodation(
        accommodation_id,
        data,
    )


@router.delete(
    "/{accommodation_id}",
    response_model=AccommodationResponse,
    summary="Mark accommodation unavailable",
    description=(
        "Admin-only soft delete for accommodations. The record is kept for "
        "history, but it is marked unavailable and hidden from public lists."
    ),
)
async def mark_accommodation_unavailable(
    accommodation_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> AccommodationResponse:
    return await AccommodationService(session).mark_accommodation_unavailable(
        accommodation_id,
    )
