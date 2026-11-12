from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import require_admin
from app.db.session import get_db_session
from app.features.destinations.schemas import (
    DestinationCreate,
    DestinationListQuery,
    DestinationResponse,
    DestinationUpdate,
)
from app.features.destinations.service import DestinationService
from app.features.users.models import User


router = APIRouter(prefix="/destinations", tags=["destinations"])


@router.get(
    "",
    response_model=list[DestinationResponse],
    summary="List destinations",
    description=(
        "Returns active destinations for traveler browsing. Use the optional "
        "query filters for simple search, district/category filtering, budget "
        "class, difficulty level, traveler-friendly flags, and pagination."
    ),
)
async def list_destinations(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    search: str | None = Query(default=None, max_length=255),
    district: str | None = Query(default=None, max_length=255),
    category: str | None = Query(default=None, max_length=500),
    budget_class: str | None = Query(default=None, max_length=50),
    difficulty_level: str | None = Query(default=None, max_length=50),
    kid_friendly: bool | None = None,
    wheelchair_accessible: bool | None = None,
    pet_friendly: bool | None = None,
    family_friendly: bool | None = None,
    couple_friendly: bool | None = None,
    group_friendly: bool | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[DestinationResponse]:
    filters = DestinationListQuery(
        search=search,
        district=district,
        category=category,
        budget_class=budget_class,
        difficulty_level=difficulty_level,
        kid_friendly=kid_friendly,
        wheelchair_accessible=wheelchair_accessible,
        pet_friendly=pet_friendly,
        family_friendly=family_friendly,
        couple_friendly=couple_friendly,
        group_friendly=group_friendly,
        limit=limit,
        offset=offset,
    )

    return await DestinationService(session).list_destinations(filters)


@router.post(
    "",
    response_model=DestinationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create destination",
    description=(
        "Admin-only endpoint for adding a destination to the catalog. The "
        "request stores readable latitude/longitude values and also prepares "
        "the PostGIS point column when the database supports it."
    ),
)
async def create_destination(
    data: DestinationCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> DestinationResponse:
    return await DestinationService(session).create_destination(data)


@router.get(
    "/{destination_id}",
    response_model=DestinationResponse,
    summary="Get destination",
    description=(
        "Returns one active destination by ID. Inactive destinations are hidden "
        "from public reads so soft-deleted places do not appear in Flutter."
    ),
)
async def get_destination(
    destination_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> DestinationResponse:
    return await DestinationService(session).get_destination(destination_id)


@router.patch(
    "/{destination_id}",
    response_model=DestinationResponse,
    summary="Update destination",
    description=(
        "Admin-only endpoint for editing destination details, filters, costs, "
        "accessibility flags, images, and coordinates."
    ),
)
async def update_destination(
    destination_id: int,
    data: DestinationUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> DestinationResponse:
    return await DestinationService(session).update_destination(destination_id, data)


@router.delete(
    "/{destination_id}",
    response_model=DestinationResponse,
    summary="Deactivate destination",
    description=(
        "Admin-only soft delete. The destination remains in the database but "
        "is marked inactive and disappears from public browse/get endpoints."
    ),
)
async def deactivate_destination(
    destination_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> DestinationResponse:
    return await DestinationService(session).deactivate_destination(destination_id)
