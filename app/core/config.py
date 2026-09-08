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

    database_url: str = Field("", validation_alias="DATABASE_URL")

    jwt_secret_key: str = ""
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7
    admin_registration_code: str = ""

    cors_allowed_origins: str = "*"

    groq_api_key: str | None = None
    groq_model_default: str | None = None
    groq_model_fast: str | None = None
    groq_model_quality: str | None = None
    groq_model_fallback: str | None = None
    groq_model_compare_a: str | None = None
    groq_model_compare_b: str | None = None
    groq_model_compare_c: str | None = None

    osrm_base_url: str | None = None

    cloudinary_cloud_name: str | None = None
    cloudinary_api_key: str | None = None
    cloudinary_api_secret: str | None = None
    cloudinary_upload_folder: str = "lakbay"

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
