from typing import Annotated

from fastapi import APIRouter, Depends, Query, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.users.models import User
from app.features.weather.schemas import (
    CurrentWeatherResponse,
    WeatherForecastResponse,
)
from app.features.weather.service import WeatherService

router = APIRouter(prefix="/weather", tags=["weather"])
destination_router = APIRouter(prefix="/destinations", tags=["weather"])


@router.get(
    "/current",
    response_model=CurrentWeatherResponse,
    status_code=status.HTTP_200_OK,
    summary="Get current weather",
    description="Protected endpoint that proxies OpenWeather current weather by coordinates.",
)
async def current_weather(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    lat: float = Query(ge=-90, le=90),
    lng: float = Query(ge=-180, le=180),
) -> CurrentWeatherResponse:
    return await WeatherService(session).current_weather(lat=lat, lng=lng)


@router.get(
    "/forecast",
    response_model=WeatherForecastResponse,
    status_code=status.HTTP_200_OK,
    summary="Get weather forecast",
    description="Protected endpoint that proxies OpenWeather 5-day forecast by coordinates.",
)
async def forecast(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    lat: float = Query(ge=-90, le=90),
    lng: float = Query(ge=-180, le=180),
    days: int = Query(default=5, ge=1, le=5),
) -> WeatherForecastResponse:
    return await WeatherService(session).forecast(lat=lat, lng=lng, days=days)


@destination_router.get(
    "/{destination_id}/weather",
    response_model=WeatherForecastResponse,
    status_code=status.HTTP_200_OK,
    summary="Get destination weather",
    description="Protected endpoint that fetches OpenWeather forecast using a destination's saved coordinates.",
)
async def destination_weather(
    destination_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    days: int = Query(default=5, ge=1, le=5),
) -> WeatherForecastResponse:
    return await WeatherService(session).destination_weather(
        destination_id=destination_id,
        days=days,
    )
