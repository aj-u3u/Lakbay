import json
from dataclasses import dataclass
from decimal import Decimal
from typing import Any

from pydantic import ValidationError

from app.features.ai.schemas import AIItineraryOption


class AIOutputValidationError(Exception):
    def __init__(self, message: str, *, details: list[str] | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.details = details or []


@dataclass(frozen=True)
class AIItineraryCatalog:
    destination_ids: set[int]
    accommodation_ids: set[int]
    transportation_ids: set[int]
    total_budget: Decimal
    day_count: int
    minimum_option_count: int


def parse_and_validate_itinerary_output(
    *,
    content: str,
    catalog: AIItineraryCatalog,
) -> list[AIItineraryOption]:
    payload = _parse_json_payload(content)
    raw_options = payload.get("options")

    if not isinstance(raw_options, list):
        raise AIOutputValidationError("AI output must contain an options list.")

    if len(raw_options) < catalog.minimum_option_count:
        raise AIOutputValidationError(
            "AI output did not include enough itinerary options.",
            details=[
                f"Expected at least {catalog.minimum_option_count} options.",
                f"Received {len(raw_options)} options.",
            ],
        )

    options: list[AIItineraryOption] = []
    errors: list[str] = []

    for index, raw_option in enumerate(raw_options, start=1):
        try:
            option = AIItineraryOption.model_validate(raw_option)
            _validate_option(option=option, catalog=catalog)
        except (ValidationError, AIOutputValidationError) as exc:
            errors.append(f"Option {index}: {exc}")
            continue

        options.append(option)

    if errors:
        raise AIOutputValidationError(
            "AI output failed itinerary validation.",
            details=errors,
        )

    if len(options) < catalog.minimum_option_count:
        raise AIOutputValidationError(
            "AI output did not include enough valid itinerary options.",
            details=[f"Valid options: {len(options)}"],
        )

    return options


def _parse_json_payload(content: str) -> dict[str, Any]:
    cleaned = content.strip()

    if cleaned.startswith("```"):
        cleaned = _strip_code_fence(cleaned)

    start = cleaned.find("{")
    end = cleaned.rfind("}")

    if start == -1 or end == -1 or end <= start:
        raise AIOutputValidationError("AI output was not valid JSON.")

    try:
        payload = json.loads(cleaned[start : end + 1])
    except json.JSONDecodeError as exc:
        raise AIOutputValidationError("AI output was not valid JSON.") from exc

    if not isinstance(payload, dict):
        raise AIOutputValidationError("AI output root must be a JSON object.")

    return payload


def _strip_code_fence(value: str) -> str:
    lines = value.splitlines()

    if lines and lines[0].startswith("```"):
        lines = lines[1:]

    if lines and lines[-1].startswith("```"):
        lines = lines[:-1]

    return "\n".join(lines).strip()


def _validate_option(*, option: AIItineraryOption, catalog: AIItineraryCatalog) -> None:
    if len(option.days) != catalog.day_count:
        raise AIOutputValidationError(
            f"Expected exactly {catalog.day_count} day(s), got {len(option.days)}."
        )

    expected_days = set(range(1, catalog.day_count + 1))
    actual_days = {day.day for day in option.days}

    if actual_days != expected_days:
        raise AIOutputValidationError("Itinerary day numbers are incomplete or invalid.")

    if option.estimated_total_cost > catalog.total_budget:
        raise AIOutputValidationError("Itinerary option exceeds the requested budget.")

    if option.is_over_budget:
        raise AIOutputValidationError("Itinerary option is marked over budget.")

    for day in option.days:
        for activity in day.activities:
            _validate_activity_ids(activity=activity, catalog=catalog)


def _validate_activity_ids(*, activity, catalog: AIItineraryCatalog) -> None:
    if (
        activity.destination_id is not None
        and activity.destination_id not in catalog.destination_ids
    ):
        raise AIOutputValidationError(
            f"Unknown destination_id {activity.destination_id}."
        )

    if (
        activity.accommodation_id is not None
        and activity.accommodation_id not in catalog.accommodation_ids
    ):
        raise AIOutputValidationError(
            f"Unknown accommodation_id {activity.accommodation_id}."
        )

    if (
        activity.transportation_id is not None
        and activity.transportation_id not in catalog.transportation_ids
    ):
        raise AIOutputValidationError(
            f"Unknown transportation_id {activity.transportation_id}."
        )
