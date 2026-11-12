from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import require_admin
from app.db.session import get_db_session
from app.features.transportations.schemas import (
    TransportationCreate,
    TransportationResponse,
    TransportationUpdate,
)
from app.features.transportations.service import TransportationService
from app.features.users.models import User


destination_router = APIRouter(
    prefix="/destinations/{destination_id}/transportations",
    tags=["transportations"],
)
router = APIRouter(prefix="/transportations", tags=["transportations"])


@destination_router.get(
    "",
    response_model=list[TransportationResponse],
    summary="List destination transportation options",
    description=(
        "Returns available transportation options for one active destination. "
        "Use this for simple fare and travel-time choices before route "
        "optimization is built."
    ),
)
async def list_destination_transportations(
    destination_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> list[TransportationResponse]:
    return await TransportationService(session).list_for_destination(
        destination_id,
    )


@destination_router.post(
    "",
    response_model=TransportationResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create destination transportation option",
    description=(
        "Admin-only endpoint for adding a fare estimate or travel option under "
        "an existing active destination."
    ),
)
async def create_destination_transportation(
    destination_id: int,
    data: TransportationCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> TransportationResponse:
    return await TransportationService(session).create_transportation(
        destination_id,
        data,
    )


@router.patch(
    "/{transportation_id}",
    response_model=TransportationResponse,
    summary="Update transportation option",
    description=(
        "Admin-only endpoint for editing vehicle type, transport mode, route "
        "text, price, duration, notes, or availability."
    ),
)
async def update_transportation(
    transportation_id: int,
    data: TransportationUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> TransportationResponse:
    return await TransportationService(session).update_transportation(
        transportation_id,
        data,
    )


@router.delete(
    "/{transportation_id}",
    response_model=TransportationResponse,
    summary="Mark transportation option unavailable",
    description=(
        "Admin-only soft delete for transportation records. The option stays "
        "in the database but is hidden from public destination transport lists."
    ),
)
async def mark_transportation_unavailable(
    transportation_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> TransportationResponse:
    return await TransportationService(session).mark_transportation_unavailable(
        transportation_id,
    )
