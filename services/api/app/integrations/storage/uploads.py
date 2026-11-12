from fastapi import UploadFile, status

from app.core.config import Settings
from app.core.exceptions import LakbayAPIError
from app.core.provider_usage import ProviderLimiter


_IMAGE_READ_CHUNK_SIZE = 64 * 1024
cloudinary_upload_limiter = ProviderLimiter()


async def read_validated_image(file: UploadFile, settings: Settings) -> bytes:
    content_type = (file.content_type or "").lower()

    if content_type not in settings.allowed_image_types:
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
        if total_bytes > settings.upload_max_image_bytes:
            raise LakbayAPIError(
                "Uploaded image is too large.",
                code="upload_too_large",
                status_code=status.HTTP_400_BAD_REQUEST,
                details={
                    "max_bytes": settings.upload_max_image_bytes,
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

    detected_content_type = detect_image_content_type(file_bytes)
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


def reserve_cloudinary_upload(*, user_id: int, settings: Settings) -> None:
    cloudinary_upload_limiter.reserve_many(
        [
            (f"cloudinary:user:{user_id}", settings.cloudinary_uploads_per_user_day, 86400, 1),
            ("cloudinary:all", settings.cloudinary_uploads_per_app_day, 86400, 1),
        ],
        code="cloudinary_upload_rate_limit_exceeded",
        message="Photo upload limit reached. Please try again later.",
    )


def detect_image_content_type(file_bytes: bytes) -> str | None:
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
