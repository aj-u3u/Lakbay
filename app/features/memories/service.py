from urllib.parse import urlsplit

from fastapi import UploadFile, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import LakbayAPIError
from app.core.provider_usage import ProviderLimiter
from app.features.memories.models import TripMemory
from app.features.memories.repository import MemoryRepository
from app.features.memories.schemas import (
    TripMemoryCreate,
    TripMemoryResponse,
    TripMemoryUpdate,
    TripMemoryUploadResponse,
)
from app.features.trips.models import Trip, TripMember
from app.features.users.models import User
from app.integrations.storage.client import CloudinaryStorageClient, StorageUploadResult


_IMAGE_READ_CHUNK_SIZE = 64 * 1024
_cloudinary_upload_limiter = ProviderLimiter()


class MemoryService:
    def __init__(
        self,
        session: AsyncSession,
        *,
        storage_client: CloudinaryStorageClient | None = None,
        settings: Settings | None = None,
    ) -> None:
        self.session = session
        self.memories = MemoryRepository(session)
        self.storage_client = storage_client
        self.settings = settings or get_settings()

    async def upload_image(
        self,
        *,
        user: User,
        trip_id: int,
        file: UploadFile,
    ) -> TripMemoryUploadResponse:
        trip, _ = await self._require_active_member(user=user, trip_id=trip_id)
        self._require_trip_mutable(trip)
        file_bytes = await self._read_validated_image(file)
        _cloudinary_upload_limiter.reserve_many(
            [
                (f"cloudinary:user:{user.user_id}", self.settings.cloudinary_uploads_per_user_day, 86400, 1),
                ("cloudinary:all", self.settings.cloudinary_uploads_per_app_day, 86400, 1),
            ],
            code="cloudinary_upload_rate_limit_exceeded",
            message="Photo upload limit reached. Please try again later.",
        )
        storage = self.storage_client or CloudinaryStorageClient(self.settings)
        result = await storage.upload_image(
            file_bytes=file_bytes,
            filename=file.filename,
            content_type=(file.content_type or "").lower(),
            folder_suffix=f"trips/{trip_id}/memories",
        )

        return _upload_response(result)

    async def create_memory(
        self,
        *,
        user: User,
        trip_id: int,
        data: TripMemoryCreate,
    ) -> TripMemoryResponse:
        trip, current_member = await self._require_active_member(
            user=user,
            trip_id=trip_id,
        )
        self._require_trip_mutable(trip)
        self._require_cloudinary_image_url(data.image_url)
        self._require_destination_belongs_to_trip(trip=trip, destination_id=data.destination_id)
        memory = TripMemory(
            trip_id=trip_id,
            uploaded_by_user_id=user.user_id,
            uploaded_by_trip_member_id=current_member.trip_member_id,
            destination_id=data.destination_id,
            image_url=data.image_url,
            cloudinary_public_id=data.cloudinary_public_id,
            caption=data.caption,
            location_tag=data.location_tag,
            taken_at=data.taken_at,
            status="active",
        )

        await self.memories.add_memory(memory)
        await self.session.commit()

        created_memory = await self._require_memory(trip_id=trip_id, memory_id=memory.trip_memory_id)

        return _memory_response(created_memory)

    async def list_memories(
        self,
        *,
        user: User,
        trip_id: int,
        include_deleted: bool,
        limit: int,
        offset: int,
    ) -> list[TripMemoryResponse]:
        _, current_member = await self._require_active_member(user=user, trip_id=trip_id)

        if include_deleted and not _is_trip_manager(current_member):
            raise LakbayAPIError(
                "You do not have permission to list deleted memories.",
                code="deleted_memories_permission_denied",
                status_code=status.HTTP_403_FORBIDDEN,
            )

        memories = await self.memories.list_memories(
            trip_id=trip_id,
            include_deleted=include_deleted,
            limit=limit,
            offset=offset,
        )

        return [_memory_response(memory) for memory in memories]

    async def get_memory(
        self,
        *,
        user: User,
        trip_id: int,
        memory_id: int,
    ) -> TripMemoryResponse:
        await self._require_active_member(user=user, trip_id=trip_id)
        memory = await self._require_memory(trip_id=trip_id, memory_id=memory_id)

        return _memory_response(memory)

    async def update_memory(
        self,
        *,
        user: User,
        trip_id: int,
        memory_id: int,
        data: TripMemoryUpdate,
    ) -> TripMemoryResponse:
        trip, current_member = await self._require_active_member(
            user=user,
            trip_id=trip_id,
        )
        self._require_trip_mutable(trip)
        memory = await self._require_memory(trip_id=trip_id, memory_id=memory_id)
        self._require_memory_editor(current_member=current_member, memory=memory)
        values = data.model_dump(exclude_unset=True)

        if not values:
            raise LakbayAPIError(
                "At least one memory field must be provided.",
                code="empty_memory_update",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if "destination_id" in values:
            self._require_destination_belongs_to_trip(
                trip=trip,
                destination_id=values["destination_id"],
            )

        for field, value in values.items():
            setattr(memory, field, value)

        await self.session.commit()
        updated_memory = await self._require_memory(trip_id=trip_id, memory_id=memory_id)

        return _memory_response(updated_memory)

    async def delete_memory(
        self,
        *,
        user: User,
        trip_id: int,
        memory_id: int,
    ) -> TripMemoryResponse:
        trip, current_member = await self._require_active_member(
            user=user,
            trip_id=trip_id,
        )
        self._require_trip_mutable(trip)
        memory = await self._require_memory(trip_id=trip_id, memory_id=memory_id)
        self._require_memory_editor(current_member=current_member, memory=memory)
        memory.status = "deleted"
        await self.session.commit()

        deleted_memory = await self._require_memory(
            trip_id=trip_id,
            memory_id=memory_id,
            include_deleted=True,
        )

        return _memory_response(deleted_memory)

    async def _read_validated_image(self, file: UploadFile) -> bytes:
        content_type = (file.content_type or "").lower()

        if content_type not in self.settings.allowed_image_types:
            raise LakbayAPIError(
                "Only JPEG, PNG, or WebP images are allowed.",
                code="invalid_image_type",
                status_code=status.HTTP_400_BAD_REQUEST,
                details={"content_type": file.content_type},
            )

        chunks: list[bytes] = []
        total_bytes = 0

        while chunk := await file.read(_IMAGE_READ_CHUNK_SIZE):
            total_bytes += len(chunk)

            if total_bytes > self.settings.upload_max_image_bytes:
                raise LakbayAPIError(
                    "Uploaded image is too large.",
                    code="upload_too_large",
                    status_code=status.HTTP_400_BAD_REQUEST,
                    details={
                        "max_bytes": self.settings.upload_max_image_bytes,
                        "actual_bytes": total_bytes,
                    },
                )

            chunks.append(chunk)

        file_bytes = b"".join(chunks)

        if not file_bytes:
            raise LakbayAPIError(
                "Uploaded image cannot be empty.",
                code="empty_upload",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        detected_content_type = _detect_image_content_type(file_bytes)

        if detected_content_type is None:
            raise LakbayAPIError(
                "Uploaded file content is not a supported image.",
                code="invalid_image_content",
                status_code=status.HTTP_400_BAD_REQUEST,
                details={"content_type": file.content_type},
            )

        if detected_content_type != content_type:
            raise LakbayAPIError(
                "Uploaded file content does not match its declared image type.",
                code="image_type_mismatch",
                status_code=status.HTTP_400_BAD_REQUEST,
                details={
                    "declared_content_type": content_type,
                    "detected_content_type": detected_content_type,
                },
            )

        return file_bytes

    async def _require_active_member(
        self,
        *,
        user: User,
        trip_id: int,
    ) -> tuple[Trip, TripMember]:
        trip = await self.memories.get_trip_with_members(trip_id=trip_id)

        if trip is None:
            raise LakbayAPIError(
                "Trip was not found.",
                code="trip_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        member = _active_member_for_user(trip, user.user_id)

        if member is None:
            raise LakbayAPIError(
                "Trip was not found.",
                code="trip_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return trip, member

    async def _require_memory(
        self,
        *,
        trip_id: int,
        memory_id: int,
        include_deleted: bool = False,
    ) -> TripMemory:
        memory = await self.memories.get_memory(
            trip_id=trip_id,
            memory_id=memory_id,
            include_deleted=include_deleted,
        )

        if memory is None:
            raise LakbayAPIError(
                "Trip memory was not found.",
                code="trip_memory_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return memory

    def _require_trip_mutable(self, trip: Trip) -> None:
        if trip.status == "archived":
            raise LakbayAPIError(
                "Archived trips are read-only for memories.",
                code="trip_archived_read_only",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

    def _require_memory_editor(
        self,
        *,
        current_member: TripMember,
        memory: TripMemory,
    ) -> None:
        if _is_trip_manager(current_member):
            return

        if memory.uploaded_by_trip_member_id == current_member.trip_member_id:
            return

        raise LakbayAPIError(
            "You do not have permission to edit this memory.",
            code="trip_memory_permission_denied",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    def _require_destination_belongs_to_trip(
        self,
        *,
        trip: Trip,
        destination_id: int | None,
    ) -> None:
        if destination_id is None:
            return

        trip_destination_ids = {
            trip_destination.destination_id
            for trip_destination in trip.destinations
        }

        if destination_id in trip_destination_ids:
            return

        raise LakbayAPIError(
            "Memory destination must belong to this trip.",
            code="trip_memory_destination_mismatch",
            status_code=status.HTTP_400_BAD_REQUEST,
            details={"destination_id": destination_id},
        )

    def _require_cloudinary_image_url(self, image_url: str) -> None:
        url = urlsplit(image_url)
        cloud_name = (self.settings.cloudinary_cloud_name or "").strip()

        if url.scheme != "https" or url.netloc.lower() != "res.cloudinary.com":
            raise LakbayAPIError(
                "Memory image URL must be a secure Cloudinary URL.",
                code="invalid_memory_image_url",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if cloud_name and not url.path.startswith(f"/{cloud_name}/"):
            raise LakbayAPIError(
                "Memory image URL must belong to the configured Cloudinary account.",
                code="invalid_memory_image_url",
                status_code=status.HTTP_400_BAD_REQUEST,
            )


def _memory_response(memory: TripMemory) -> TripMemoryResponse:
    return TripMemoryResponse(
        trip_memory_id=memory.trip_memory_id,
        trip_id=memory.trip_id,
        uploaded_by_user_id=memory.uploaded_by_user_id,
        uploaded_by_trip_member_id=memory.uploaded_by_trip_member_id,
        uploaded_by_full_name=memory.uploaded_by_member.user.full_name,
        uploaded_by_email=memory.uploaded_by_member.user.email,
        destination_id=memory.destination_id,
        destination_name=(memory.destination.name if memory.destination is not None else None),
        image_url=memory.image_url,
        cloudinary_public_id=memory.cloudinary_public_id,
        caption=memory.caption,
        location_tag=memory.location_tag,
        taken_at=memory.taken_at,
        status=memory.status,
        like_count=memory.like_count,
        comment_count=memory.comment_count,
        created_at=memory.created_at,
        updated_at=memory.updated_at,
    )


def _upload_response(result: StorageUploadResult) -> TripMemoryUploadResponse:
    return TripMemoryUploadResponse(
        image_url=result.image_url,
        cloudinary_public_id=result.cloudinary_public_id,
        original_filename=result.original_filename,
        content_type=result.content_type,
        bytes=result.bytes,
        width=result.width,
        height=result.height,
        format=result.format,
        resource_type=result.resource_type,
    )


def _active_member_for_user(trip: Trip, user_id: int) -> TripMember | None:
    return next(
        (
            member
            for member in trip.members
            if member.user_id == user_id and member.status == "active"
        ),
        None,
    )


def _is_trip_manager(member: TripMember) -> bool:
    return member.role in {"owner", "organizer"}


def _detect_image_content_type(file_bytes: bytes) -> str | None:
    if file_bytes.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"

    if file_bytes.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"

    if (
        len(file_bytes) >= 12
        and file_bytes.startswith(b"RIFF")
        and file_bytes[8:12] == b"WEBP"
    ):
        return "image/webp"

    return None
