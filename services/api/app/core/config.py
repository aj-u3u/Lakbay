from functools import lru_cache
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "Lakbay API"
    app_env: str = "local"
    api_v1_prefix: str = "/api/v1"
    timezone: str = "Asia/Manila"
    debug: bool = False
    log_level: str = "INFO"
    provider_usage_redis_url: str | None = None

    database_url: str = Field("", validation_alias="DATABASE_URL")

    jwt_secret_key: str = ""
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7
    admin_registration_code: str = ""

    cors_allowed_origins: str = "*"
    cors_allowed_origin_regex: str | None = None

    groq_api_key: str | None = None
    groq_model_default: str | None = None
    groq_model_fast: str | None = None
    groq_model_quality: str | None = None
    groq_model_fallback: str | None = None
    groq_model_compare_a: str | None = None
    groq_model_compare_b: str | None = None
    groq_model_compare_c: str | None = None
    groq_base_url: str = "https://api.groq.com/openai/v1"
    groq_request_timeout_seconds: int = Field(default=60, ge=1, le=300)
    groq_max_retries: int = Field(default=1, ge=0, le=3)
    groq_temperature: float = Field(default=0.3, ge=0, le=2)
    groq_max_tokens: int = Field(default=4096, ge=256, le=32768)
    groq_user_requests_per_minute: int = Field(default=20, ge=1, le=120)
    groq_model_requests_per_minute: int = Field(default=20, ge=1, le=120)
    groq_model_requests_per_day: int = Field(default=1000, ge=1, le=14400)
    # Short rate-limit waits are slept through and retried instead of failing the request.
    groq_rate_limit_max_wait_seconds: int = Field(default=3, ge=0, le=10)

    # Optional second OpenAI-compatible provider (e.g. Gemini) used as the fallback
    # when the primary Groq model is rate limited. Needs its own quota to be useful.
    fallback_llm_api_key: str | None = None
    fallback_llm_base_url: str = "https://generativelanguage.googleapis.com/v1beta/openai"
    fallback_llm_model: str | None = None
    fallback_llm_requests_per_minute: int = Field(default=10, ge=1, le=120)
    fallback_llm_requests_per_day: int = Field(default=200, ge=1, le=14400)

    ai_itinerary_option_count: int = Field(default=5, ge=1, le=10)
    ai_model_comparison_enabled: bool = False

    osrm_base_url: str | None = None
    overpass_base_url: str = "https://overpass-api.de/api/interpreter"
    overpass_request_timeout_seconds: int = Field(default=15, ge=1, le=60)
    overpass_requests_per_minute: int = Field(default=10, ge=1, le=60)
    osrm_walking_base_url: str | None = None
    osrm_request_timeout_seconds: int = Field(default=30, ge=1, le=120)
    osrm_profile_driving: str = "driving"
    osrm_profile_walking: str = "walking"
    route_max_destinations: int = Field(default=10, ge=1, le=25)
    route_requests_per_minute: int = Field(default=10, ge=1, le=120)
    geo_group_requests_per_minute: int = Field(default=10, ge=1, le=120)
    planning_route_requests_per_minute: int = Field(default=10, ge=1, le=120)

    google_routes_api_key: str | None = None
    google_routes_base_url: str = "https://routes.googleapis.com"
    google_routes_request_timeout_seconds: int = Field(default=20, ge=1, le=120)
    google_routes_cache_ttl_seconds: int = Field(default=300, ge=0, le=3600)
    google_routes_daily_request_limit: int = Field(default=150, ge=0, le=10000)

    openweather_api_key: str | None = None
    openweather_base_url: str = "https://api.openweathermap.org/data/2.5"
    openweather_units: str = "metric"
    openweather_lang: str = "en"
    openweather_request_timeout_seconds: int = Field(default=20, ge=1, le=120)
    openweather_requests_per_minute: int = Field(default=45, ge=1, le=60)
    openweather_requests_per_30_days: int = Field(default=100000, ge=1, le=1000000)
    openweather_current_cache_seconds: int = Field(default=600, ge=0, le=3600)
    openweather_forecast_cache_seconds: int = Field(default=3600, ge=0, le=10800)

    cloudinary_cloud_name: str | None = None
    cloudinary_api_key: str | None = None
    cloudinary_api_secret: str | None = None
    cloudinary_upload_folder: str = "lakbay"
    cloudinary_uploads_per_user_day: int = Field(default=10, ge=1, le=1000)
    cloudinary_uploads_per_app_day: int = Field(default=50, ge=1, le=10000)
    upload_max_image_bytes: int = Field(default=5_242_880, ge=1)
    upload_allowed_image_types: str = "image/jpeg,image/png,image/webp"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    @property
    def sqlalchemy_database_url(self) -> str:
        url = self.database_url

        if not url:
            raise ValueError("DATABASE_URL is required for database operations.")

        if url.startswith("postgres://"):
            url = url.replace("postgres://", "postgresql://", 1)

        if url.startswith("postgresql://"):
            url = url.replace("postgresql://", "postgresql+asyncpg://", 1)

        return _normalize_asyncpg_url(url)

    @property
    def cors_origins(self) -> list[str]:
        value = self.cors_allowed_origins.strip()

        if value == "*":
            return ["*"]

        return [origin.strip() for origin in value.split(",") if origin.strip()]

    @property
    def cors_allow_credentials(self) -> bool:
        return self.cors_origins != ["*"]

    @property
    def allowed_image_types(self) -> set[str]:
        return {
            content_type.strip().lower()
            for content_type in self.upload_allowed_image_types.split(",")
            if content_type.strip()
        }


def _normalize_asyncpg_url(url: str) -> str:
    if not url.startswith("postgresql+asyncpg://"):
        return url

    parts = urlsplit(url)
    query_items = parse_qsl(parts.query, keep_blank_values=True)

    normalized_items: list[tuple[str, str]] = []
    has_ssl = any(key == "ssl" for key, _ in query_items)

    for key, value in query_items:
        if key == "sslmode":
            if not has_ssl:
                normalized_items.append(("ssl", value))
            continue

        if key == "channel_binding":
            continue

        normalized_items.append((key, value))

    return urlunsplit(
        (
            parts.scheme,
            parts.netloc,
            parts.path,
            urlencode(normalized_items),
            parts.fragment,
        )
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
