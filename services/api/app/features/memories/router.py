from typing import Annotated

from fastapi import APIRouter, Depends, File, Query, UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.memories.schemas import (
    TripMemoryCreate,
    TripMemoryResponse,
    TripMemoryUpdate,
    TripMemoryUploadResponse,
)
from app.features.memories.service import MemoryService
from app.features.users.models import User
from app.integrations.storage.client import CloudinaryStorageClient, get_storage_client


router = APIRouter(prefix="/trips/{trip_id}/memories", tags=["memories"])


@router.post(
    "/upload",
    response_model=TripMemoryUploadResponse,
    summary="Upload trip memory image",
    description=(
        "Protected multipart endpoint that uploads one trip memory image to "
        "Cloudinary and returns the image URL to save in a memory record."
    ),
)
async def upload_trip_memory_image(
    trip_id: int,
    file: Annotated[UploadFile, File(...)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    storage_client: Annotated[CloudinaryStorageClient, Depends(get_storage_client)],
) -> TripMemoryUploadResponse:
    return await MemoryService(
        session,
        storage_client=storage_client,
    ).upload_image(
        user=current_user,
        trip_id=trip_id,
        file=file,
    )


@router.post(
    "",
    response_model=TripMemoryResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create trip memory",
    description=(
        "Protected endpoint that saves a trip memory using an uploaded image URL, "
        "caption, optional location tag, and optional destination."
    ),
)
async def create_trip_memory(
    trip_id: int,
    data: TripMemoryCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripMemoryResponse:
    return await MemoryService(session).create_memory(
        user=current_user,
        trip_id=trip_id,
        data=data,
    )


@router.get(
    "",
    response_model=list[TripMemoryResponse],
    summary="List trip memories",
    description="Protected endpoint that lists active memories for a shared trip.",
)
async def list_trip_memories(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    include_deleted: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[TripMemoryResponse]:
    return await MemoryService(session).list_memories(
        user=current_user,
        trip_id=trip_id,
        include_deleted=include_deleted,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/{memory_id}",
    response_model=TripMemoryResponse,
    summary="Get trip memory",
    description="Protected endpoint that returns one active memory from a shared trip.",
)
async def get_trip_memory(
    trip_id: int,
    memory_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripMemoryResponse:
    return await MemoryService(session).get_memory(
        user=current_user,
        trip_id=trip_id,
        memory_id=memory_id,
    )


@router.patch(
    "/{memory_id}",
    response_model=TripMemoryResponse,
    summary="Update trip memory",
    description=(
        "Protected endpoint that lets the uploader, owner, or organizer update "
        "memory metadata."
    ),
)
async def update_trip_memory(
    trip_id: int,
    memory_id: int,
    data: TripMemoryUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripMemoryResponse:
    return await MemoryService(session).update_memory(
        user=current_user,
        trip_id=trip_id,
        memory_id=memory_id,
        data=data,
    )


@router.delete(
    "/{memory_id}",
    response_model=TripMemoryResponse,
    summary="Delete trip memory",
    description=(
        "Protected soft delete. The memory remains in the database and is marked "
        "deleted so it is hidden from normal memory lists."
    ),
)
async def delete_trip_memory(
    trip_id: int,
    memory_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripMemoryResponse:
    return await MemoryService(session).delete_memory(
        user=current_user,
        trip_id=trip_id,
        memory_id=memory_id,
    )
