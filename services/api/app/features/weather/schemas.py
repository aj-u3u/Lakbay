from datetime import date, datetime

from pydantic import BaseModel, Field


class WeatherCondition(BaseModel):
    code: int | None = None
    main: str
    description: str
    icon: str | None = None


class CurrentWeatherResponse(BaseModel):
    provider: str = "openweather"
    location_name: str | None = None
    lat: float
    lng: float
    observed_at: datetime | None = None
    temp_c: float | None = None
    feels_like_c: float | None = None
    temp_min_c: float | None = None
    temp_max_c: float | None = None
    humidity_percent: int | None = None
    wind_speed_mps: float | None = None
    clouds_percent: int | None = None
    rain_1h_mm: float | None = None
    condition: WeatherCondition
    advisory: str


class WeatherForecastDay(BaseModel):
    date: date
    temp_min_c: float | None = None
    temp_max_c: float | None = None
    temp_avg_c: float | None = None
    rain_chance_percent: int = Field(ge=0, le=100)
    condition: WeatherCondition
    advisory: str


class WeatherForecastResponse(BaseModel):
    provider: str = "openweather"
    location_name: str | None = None
    lat: float
    lng: float
    days: list[WeatherForecastDay]
    current: CurrentWeatherResponse | None = None
