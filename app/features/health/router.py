from fastapi import APIRouter

from app.core.config import get_settings
from app.features.health.schemas import HealthResponse


router = APIRouter(prefix="/health", tags=["health"])


@router.get("", response_model=HealthResponse, summary="Check API health")
async def check_health() -> HealthResponse:
    settings = get_settings()

    return HealthResponse(
        status="ok",
        app_name=settings.app_name,
        environment=settings.app_env,
        api_prefix=settings.api_v1_prefix,
        timezone=settings.timezone,
    )
