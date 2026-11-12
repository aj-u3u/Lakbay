"""Read-only provider status and quota snapshot. Run from the repository root."""

import argparse
import sys
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import Settings, get_settings  # noqa: E402


def _number(value):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) else None


def _metric(body: dict, name: str) -> dict:
    value = body.get(name)
    if not isinstance(value, dict):
        return {}
    return {
        key: number
        for key in ("usage", "limit", "used_percent")
        if (number := _number(value.get(key))) is not None
    }


def check_providers(settings: Settings, client: httpx.Client) -> dict:
    """Return only status and quota fields; never retain provider response bodies."""
    result: dict = {}

    if settings.groq_api_key:
        try:
            response = client.get(
                settings.groq_base_url.rstrip("/") + "/models",
                headers={"Authorization": f"Bearer {settings.groq_api_key}"},
            )
            entry: dict = {"status": response.status_code}
            if response.status_code == 200:
                body = response.json()
                available = {
                    item.get("id") for item in body.get("data", [])
                    if isinstance(item, dict)
                }
                entry["configured_models_listed"] = {
                    role: bool(model in available)
                    for role in ("default", "compare_a", "compare_b", "compare_c")
                    if (model := getattr(settings, "groq_model_" + role))
                }
                for header, label in (
                    ("x-ratelimit-remaining-requests", "remaining_daily_requests"),
                    ("x-ratelimit-remaining-tokens", "remaining_minute_tokens"),
                ):
                    raw = response.headers.get(header)
                    if raw is not None and raw.isdigit():
                        entry[label] = int(raw)
            result["groq"] = entry
        except (httpx.RequestError, ValueError, TypeError):
            result["groq"] = {"status": "connection_or_response_error"}
    else:
        result["groq"] = {"status": "not_configured"}

    if settings.openweather_api_key:
        weather: dict = {}
        for path in ("weather", "forecast"):
            try:
                response = client.get(
                    settings.openweather_base_url.rstrip("/") + "/" + path,
                    params={
                        "lat": 7.0731,
                        "lon": 125.6128,
                        "appid": settings.openweather_api_key,
                        "units": settings.openweather_units,
                        **({"cnt": 1} if path == "forecast" else {}),
                    },
                )
                weather[path] = response.status_code
            except httpx.RequestError:
                weather[path] = "connection_error"
        result["openweather"] = weather
    else:
        result["openweather"] = {"status": "not_configured"}

    if all((settings.cloudinary_cloud_name, settings.cloudinary_api_key,
            settings.cloudinary_api_secret)):
        try:
            response = client.get(
                "https://api.cloudinary.com/v1_1/"
                + settings.cloudinary_cloud_name + "/usage",
                auth=(settings.cloudinary_api_key, settings.cloudinary_api_secret),
            )
            entry = {"status": response.status_code}
            if response.status_code == 200:
                body = response.json()
                if isinstance(body, dict):
                    entry["last_updated"] = body.get("last_updated")
                    for name in ("credits", "storage", "bandwidth", "transformations"):
                        metric = _metric(body, name)
                        if metric:
                            entry[name] = metric
                    entry["alert"] = any(
                        entry.get(name, {}).get("used_percent", 0) >= 80
                        for name in ("credits", "storage", "bandwidth", "transformations")
                    )
            result["cloudinary"] = entry
        except (httpx.RequestError, ValueError, TypeError):
            result["cloudinary"] = {"status": "connection_or_response_error"}
    else:
        result["cloudinary"] = {"status": "not_configured"}

    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--live", action="store_true", help="Make four read-only provider calls")
    args = parser.parse_args()
    if not args.live:
        parser.print_help()
        return 0

    with httpx.Client(timeout=20) as client:
        snapshot = check_providers(get_settings(), client)
    for provider, values in snapshot.items():
        print(f"{provider}: {values}")
    return 0 if all(
        value.get("status", value.get("weather")) == 200
        if provider != "openweather" else all(code == 200 for code in value.values())
        for provider, value in snapshot.items()
    ) else 1


if __name__ == "__main__":
    raise SystemExit(main())
