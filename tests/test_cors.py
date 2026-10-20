from fastapi.middleware.cors import CORSMiddleware
from starlette.datastructures import Headers

from app.core.config import get_settings
from app.main import create_app


def _login_preflight(origin: str):
    app = create_app()
    cors_settings = next(
        middleware.kwargs
        for middleware in app.user_middleware
        if middleware.cls is CORSMiddleware
    )
    cors = CORSMiddleware(app, **cors_settings)
    return cors.preflight_response(
        Headers(
            {
                "Origin": origin,
                "Access-Control-Request-Method": "POST",
                "Access-Control-Request-Headers": "content-type",
            }
        )
    )


def test_login_preflight_accepts_localhost_any_port_and_explicit_origin(
    monkeypatch,
) -> None:
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "https://admin.example.com")
    monkeypatch.setenv(
        "CORS_ALLOWED_ORIGIN_REGEX",
        r"^https?://(?:localhost|127\.0\.0\.1)(?::[0-9]+)?$",
    )
    get_settings.cache_clear()

    for origin in (
        "http://localhost:51047",
        "http://127.0.0.1:5173",
        "https://admin.example.com",
    ):
        response = _login_preflight(origin)
        assert response.status_code == 200
        assert response.headers["access-control-allow-origin"] == origin


def test_login_preflight_rejects_unlisted_websites(monkeypatch) -> None:
    monkeypatch.setenv("CORS_ALLOWED_ORIGINS", "https://admin.example.com")
    monkeypatch.setenv(
        "CORS_ALLOWED_ORIGIN_REGEX",
        r"^https?://(?:localhost|127\.0\.0\.1)(?::[0-9]+)?$",
    )
    get_settings.cache_clear()

    for origin in (
        "https://untrusted.example.com",
        "http://localhost.evil.example.com:51047",
    ):
        response = _login_preflight(origin)
        assert response.status_code == 400
        assert "access-control-allow-origin" not in response.headers
