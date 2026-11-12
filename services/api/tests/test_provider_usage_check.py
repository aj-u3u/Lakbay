import httpx

from app.core.config import Settings
from scripts.check_provider_usage import check_providers


def test_read_only_snapshot_reports_quotas_without_secrets():
    requests = []

    def handler(request):
        requests.append(request)
        if request.url.path.endswith("/models"):
            return httpx.Response(
                200,
                headers={
                    "x-ratelimit-remaining-requests": "100",
                    "x-ratelimit-remaining-tokens": "7000",
                },
                json={"data": [{"id": "model-a"}]},
            )
        if request.url.path.endswith("/usage"):
            return httpx.Response(
                200,
                json={"last_updated": "2026-11-03", "credits": {
                    "usage": 20, "limit": 25, "used_percent": 80,
                }},
            )
        return httpx.Response(200, json={})

    settings = Settings(
        _env_file=None,
        groq_api_key="secret-groq",
        groq_model_default="model-a",
        openweather_api_key="secret-weather",
        cloudinary_cloud_name="demo",
        cloudinary_api_key="secret-cloud-key",
        cloudinary_api_secret="secret-cloud-secret",
    )
    with httpx.Client(transport=httpx.MockTransport(handler)) as client:
        result = check_providers(settings, client)

    assert len(requests) == 4
    assert result["groq"]["configured_models_listed"]["default"] is True
    assert result["groq"]["remaining_minute_tokens"] == 7000
    assert result["openweather"] == {"weather": 200, "forecast": 200}
    assert result["cloudinary"]["alert"] is True
    assert "secret-" not in repr(result)


def test_snapshot_handles_provider_errors_without_returning_body():
    settings = Settings(_env_file=None, groq_api_key="secret-groq")
    with httpx.Client(
        transport=httpx.MockTransport(lambda request: httpx.Response(
            401, json={"error": "secret-groq"},
        ))
    ) as client:
        result = check_providers(settings, client)

    assert result["groq"] == {"status": 401}
    assert "secret-groq" not in repr(result)
