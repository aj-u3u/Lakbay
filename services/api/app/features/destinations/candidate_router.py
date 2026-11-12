from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import require_admin
from app.core.exceptions import LakbayAPIError
from app.db.session import get_db_session
from app.features.destinations.candidate_schemas import (
    CandidateReject,
    CandidateCreate,
    CandidateResponse,
    CandidateStatus,
    CandidateUpdate,
)
from app.features.destinations.candidate_service import CandidateService
from app.features.destinations.osm_lookup import OSMLookupService
from app.features.destinations.osm_schemas import OSMMatch, OSMSuggestionResponse
from app.core.config import get_settings
from app.core.provider_usage import ProviderLimiter
from app.features.users.models import User


router = APIRouter(prefix="/admin/destination-candidates", tags=["destination candidates"])
_osm_lookup_limiter = ProviderLimiter()


def _osm_lookup(session: AsyncSession, admin: User) -> OSMLookupService:
    """Build a lookup whose provider calls, not cache hits, count toward the admin's limit."""

    def reserve() -> None:
        _osm_lookup_limiter.reserve(
            f"osm:admin:{admin.user_id}",
            limit=get_settings().overpass_requests_per_minute,
            code="osm_lookup_rate_limited",
            message="Too many OSM lookups. Please try again shortly.",
        )

    return OSMLookupService(session, before_provider_call=reserve)


@router.get("/osm/search", response_model=list[OSMMatch])
async def search_osm_places(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
    name: str = Query(min_length=2, max_length=80),
    lat: float = Query(ge=-90, le=90),
    lng: float = Query(ge=-180, le=180),
    radius_m: int = Query(default=3000, ge=100, le=5000),
) -> list[OSMMatch]:
    if len(name.strip()) < 2:
        raise LakbayAPIError("Enter at least two non-space name characters.", code="invalid_osm_search")
    return await _osm_lookup(session, admin).search(
        name=name, lat=lat, lng=lng, radius_m=radius_m
    )


@router.get("/osm/{osm_type}/{osm_id}/suggestions", response_model=OSMSuggestionResponse)
async def get_osm_suggestions(
    osm_type: str,
    osm_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> OSMSuggestionResponse:
    if osm_type not in {"node", "way", "relation"} or osm_id < 1:
        raise LakbayAPIError("Invalid OSM identity.", code="invalid_osm_identity")
    return await _osm_lookup(session, admin).place_suggestions(osm_type=osm_type, osm_id=osm_id)


@router.get("/{candidate_id}/osm-suggestions", response_model=OSMSuggestionResponse)
async def get_candidate_osm_suggestions(
    candidate_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> OSMSuggestionResponse:
    return await _osm_lookup(session, admin).candidate_suggestions(candidate_id)


@router.post("", response_model=CandidateResponse, status_code=status.HTTP_201_CREATED)
async def stage_candidate(
    data: CandidateCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).create(data)


@router.get("", response_model=list[CandidateResponse])
async def list_candidates(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
    review_status: CandidateStatus | None = None,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[CandidateResponse]:
    return await CandidateService(session).list(
        review_status=review_status, limit=limit, offset=offset
    )


@router.get("/{candidate_id}", response_model=CandidateResponse)
async def get_candidate(
    candidate_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).get(candidate_id)


@router.patch("/{candidate_id}", response_model=CandidateResponse)
async def update_candidate(
    candidate_id: int,
    data: CandidateUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).update(candidate_id, data)


@router.post("/{candidate_id}/reject", response_model=CandidateResponse)
async def reject_candidate(
    candidate_id: int,
    data: CandidateReject,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).reject(candidate_id, data.reason)


@router.post("/{candidate_id}/publish", response_model=CandidateResponse)
async def publish_candidate(
    candidate_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    admin: Annotated[User, Depends(require_admin)],
) -> CandidateResponse:
    return await CandidateService(session).publish(candidate_id)
