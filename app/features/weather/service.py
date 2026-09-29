from collections import Counter, defaultdict
from datetime import UTC, date, datetime
from statistics import mean
from typing import Any

import httpx
from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import LakbayAPIError
from app.features.destinations.repository import DestinationRepository
from app.features.weather.schemas import (
    CurrentWeatherResponse,
    WeatherCondition,
    WeatherForecastDay,
    WeatherForecastResponse,
)


class WeatherService:
    def __init__(self, session: AsyncSession, settings: Settings | None = None) -> None:
        self.destinations = DestinationRepository(session)
        self.settings = settings or get_settings()

    async def current_weather(
        self,
        *,
        lat: float,
        lng: float,
    ) -> CurrentWeatherResponse:
        payload = await self._openweather_get(
            "/weather",
            lat=lat,
            lng=lng,
        )
        return _current_response(payload, fallback_lat=lat, fallback_lng=lng)

    async def forecast(
        self,
        *,
        lat: float,
        lng: float,
        days: int = 5,
    ) -> WeatherForecastResponse:
        current = await self.current_weather(lat=lat, lng=lng)
        payload = await self._openweather_get(
            "/forecast",
            lat=lat,
            lng=lng,
            extra_params={"cnt": min(days * 8, 40)},
        )

        return _forecast_response(
            payload,
            fallback_lat=lat,
            fallback_lng=lng,
            days=days,
            current=current,
        )

    async def destination_weather(
        self,
        *,
        destination_id: int,
        days: int = 5,
    ) -> WeatherForecastResponse:
        destination = await self.destinations.get_by_id(destination_id)
        if destination is None:
            raise LakbayAPIError(
                "Destination was not found.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        forecast = await self.forecast(
            lat=float(destination.lat),
            lng=float(destination.lng),
            days=days,
        )
        forecast.location_name = destination.name
        if forecast.current is not None:
            forecast.current.location_name = destination.name
        return forecast

    async def _openweather_get(
        self,
        path: str,
        *,
        lat: float,
        lng: float,
        extra_params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        if not self.settings.openweather_api_key:
            raise LakbayAPIError(
                "OPENWEATHER_API_KEY is not configured.",
                code="openweather_not_configured",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        params: dict[str, Any] = {
            "lat": lat,
            "lon": lng,
            "appid": self.settings.openweather_api_key,
            "units": self.settings.openweather_units,
            "lang": self.settings.openweather_lang,
        }
        if extra_params:
            params.update(extra_params)

        try:
            async with httpx.AsyncClient(
                base_url=self.settings.openweather_base_url.rstrip("/"),
                timeout=self.settings.openweather_request_timeout_seconds,
            ) as client:
                response = await client.get(path, params=params)
        except httpx.RequestError as exc:
            raise LakbayAPIError(
                "OpenWeather request failed.",
                code="openweather_request_failed",
                status_code=status.HTTP_502_BAD_GATEWAY,
            ) from exc

        if response.status_code >= 400:
            raise LakbayAPIError(
                _openweather_error_message(response),
                code="openweather_error",
                status_code=status.HTTP_502_BAD_GATEWAY,
                details={"status_code": response.status_code},
            )

        try:
            body = response.json()
        except ValueError as exc:
            raise LakbayAPIError(
                "OpenWeather returned an invalid JSON response.",
                code="openweather_invalid_response",
                status_code=status.HTTP_502_BAD_GATEWAY,
            ) from exc

        if not isinstance(body, dict):
            raise LakbayAPIError(
                "OpenWeather response shape was not recognized.",
                code="openweather_invalid_response",
                status_code=status.HTTP_502_BAD_GATEWAY,
            )

        return body


def _current_response(
    payload: dict[str, Any],
    *,
    fallback_lat: float,
    fallback_lng: float,
) -> CurrentWeatherResponse:
    coord = payload.get("coord") if isinstance(payload.get("coord"), dict) else {}
    main = payload.get("main") if isinstance(payload.get("main"), dict) else {}
    wind = payload.get("wind") if isinstance(payload.get("wind"), dict) else {}
    clouds = payload.get("clouds") if isinstance(payload.get("clouds"), dict) else {}
    rain = payload.get("rain") if isinstance(payload.get("rain"), dict) else {}
    condition = _condition_from(payload)

    return CurrentWeatherResponse(
        location_name=payload.get("name"),
        lat=_float(coord.get("lat"), fallback=fallback_lat),
        lng=_float(coord.get("lon"), fallback=fallback_lng),
        observed_at=_datetime_from_unix(payload.get("dt")),
        temp_c=_float_or_none(main.get("temp")),
        feels_like_c=_float_or_none(main.get("feels_like")),
        temp_min_c=_float_or_none(main.get("temp_min")),
        temp_max_c=_float_or_none(main.get("temp_max")),
        humidity_percent=_int_or_none(main.get("humidity")),
        wind_speed_mps=_float_or_none(wind.get("speed")),
        clouds_percent=_int_or_none(clouds.get("all")),
        rain_1h_mm=_float_or_none(rain.get("1h")),
        condition=condition,
        advisory=_advisory(condition.main, _float_or_none(main.get("temp")), _int_or_none(main.get("humidity")), _float_or_none(wind.get("speed")), _float_or_none(rain.get("1h")), None),
    )


def _forecast_response(
    payload: dict[str, Any],
    *,
    fallback_lat: float,
    fallback_lng: float,
    days: int,
    current: CurrentWeatherResponse | None,
) -> WeatherForecastResponse:
    city = payload.get("city") if isinstance(payload.get("city"), dict) else {}
    coord = city.get("coord") if isinstance(city.get("coord"), dict) else {}
    grouped: dict[date, list[dict[str, Any]]] = defaultdict(list)

    raw_items = payload.get("list") if isinstance(payload.get("list"), list) else []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        timestamp = _datetime_from_unix(item.get("dt"))
        if timestamp is None:
            continue
        grouped[timestamp.date()].append(item)

    forecast_days = []
    for forecast_date in sorted(grouped.keys())[:days]:
        forecast_days.append(_forecast_day(forecast_date, grouped[forecast_date]))

    return WeatherForecastResponse(
        location_name=city.get("name") or payload.get("name"),
        lat=_float(coord.get("lat"), fallback=fallback_lat),
        lng=_float(coord.get("lon"), fallback=fallback_lng),
        days=forecast_days,
        current=current,
    )


def _forecast_day(forecast_date: date, items: list[dict[str, Any]]) -> WeatherForecastDay:
    temps = [_float_or_none((item.get("main") or {}).get("temp")) for item in items]
    temps = [temp for temp in temps if temp is not None]
    pop_values = [_float(item.get("pop"), fallback=0.0) for item in items]
    condition = _dominant_condition(items)
    rain_chance = int(round(max(pop_values, default=0.0) * 100))
    temp_avg = round(mean(temps), 1) if temps else None
    temp_min = round(min(temps), 1) if temps else None
    temp_max = round(max(temps), 1) if temps else None

    return WeatherForecastDay(
        date=forecast_date,
        temp_min_c=temp_min,
        temp_max_c=temp_max,
        temp_avg_c=temp_avg,
        rain_chance_percent=rain_chance,
        condition=condition,
        advisory=_advisory(condition.main, temp_avg, None, None, None, rain_chance),
    )


def _dominant_condition(items: list[dict[str, Any]]) -> WeatherCondition:
    conditions = [_condition_from(item) for item in items]
    if not conditions:
        return WeatherCondition(main="Unknown", description="No forecast", icon=None)

    counts = Counter(condition.main for condition in conditions)
    dominant_main = counts.most_common(1)[0][0]
    for condition in conditions:
        if condition.main == dominant_main:
            return condition
    return conditions[0]


def _condition_from(payload: dict[str, Any]) -> WeatherCondition:
    weather = payload.get("weather")
    if isinstance(weather, list) and weather and isinstance(weather[0], dict):
        first = weather[0]
        return WeatherCondition(
            code=_int_or_none(first.get("id")),
            main=first.get("main") or "Unknown",
            description=first.get("description") or "No description",
            icon=first.get("icon"),
        )
    return WeatherCondition(main="Unknown", description="No description", icon=None)


def _advisory(
    condition_main: str,
    temp_c: float | None,
    humidity: int | None,
    wind_speed: float | None,
    rain_1h: float | None,
    rain_chance: int | None,
) -> str:
    lower = condition_main.lower()
    if rain_1h and rain_1h > 0:
        return "Rain is active now. Bring rain gear and keep a backup indoor plan."
    if rain_chance is not None and rain_chance >= 70:
        return "High rain chance. Prefer indoor stops, museums, cafes, or flexible routes."
    if "thunder" in lower:
        return "Thunderstorm risk. Avoid exposed hikes, water activities, and boat travel."
    if "rain" in lower or "drizzle" in lower:
        return "Wet weather possible. Pack an umbrella and protect electronics."
    if wind_speed is not None and wind_speed >= 10:
        return "Windy conditions. Be careful with sea crossings and exposed viewpoints."
    if temp_c is not None and temp_c >= 33:
        return "Hot day. Start early, hydrate often, and schedule shaded breaks."
    if humidity is not None and humidity >= 85:
        return "Humid conditions. Choose lighter activities and carry water."
    if "clear" in lower:
        return "Clear weather. Good for outdoor sightseeing and photo stops."
    return "Weather looks manageable. Keep plans flexible and check again before leaving."


def _openweather_error_message(response: httpx.Response) -> str:
    try:
        body = response.json()
        message = body.get("message")
        if isinstance(message, str) and message:
            return message
    except ValueError:
        pass
    return "OpenWeather rejected the request."


def _datetime_from_unix(value: Any) -> datetime | None:
    parsed = _int_or_none(value)
    if parsed is None:
        return None
    return datetime.fromtimestamp(parsed, tz=UTC)


def _float(value: Any, *, fallback: float) -> float:
    parsed = _float_or_none(value)
    return fallback if parsed is None else parsed


def _float_or_none(value: Any) -> float | None:
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None


def _int_or_none(value: Any) -> int | None:
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if isinstance(value, str):
        try:
            return int(float(value))
        except ValueError:
            return None
    return None
