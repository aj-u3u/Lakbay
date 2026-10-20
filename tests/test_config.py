from app.core.config import Settings


def test_database_url_is_required_for_database_operations() -> None:
    settings = Settings(DATABASE_URL="")

    try:
        settings.sqlalchemy_database_url
    except ValueError as exc:
        assert "DATABASE_URL is required" in str(exc)
    else:
        raise AssertionError("Expected DATABASE_URL validation error")


def test_neon_url_is_normalized_for_asyncpg() -> None:
    settings = Settings(
        DATABASE_URL=(
            "postgresql://user:pass@example.neon.tech/lakbay"
            "?sslmode=require&channel_binding=require"
        )
    )

    assert settings.sqlalchemy_database_url == (
        "postgresql+asyncpg://user:pass@example.neon.tech/lakbay?ssl=require"
    )


def test_cors_origins_accepts_wildcard() -> None:
    settings = Settings(
        DATABASE_URL="postgresql+asyncpg://user:pass@localhost/db",
        cors_allowed_origins="*",
    )

    assert settings.cors_origins == ["*"]
    assert settings.cors_allow_credentials is False


def test_cors_origins_accepts_comma_separated_values() -> None:
    settings = Settings(
        DATABASE_URL="postgresql+asyncpg://user:pass@localhost/db",
        cors_allowed_origins="http://localhost:3000, https://example.com",
    )

    assert settings.cors_origins == ["http://localhost:3000", "https://example.com"]
    assert settings.cors_allow_credentials is True
