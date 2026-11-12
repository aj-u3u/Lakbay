"""Groq strict output shape for itinerary drafts.

The local Pydantic and business validators remain responsible for budgets,
catalog IDs, day counts, and the minimum number of options.
"""

ITINERARY_RESPONSE_FORMAT = {
    "type": "json_schema",
    "json_schema": {
        "name": "lakbay_itinerary_options",
        "strict": True,
        "schema": {
            "type": "object",
            "properties": {
                "options": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "option_number": {"type": "integer"},
                            "title": {"type": "string"},
                            "summary": {"type": "string"},
                            "estimated_total_cost": {"type": "string"},
                            "is_over_budget": {"type": "boolean"},
                            "days": {
                                "type": "array",
                                "items": {
                                    "type": "object",
                                    "properties": {
                                        "day": {"type": "integer"},
                                        "title": {"type": "string"},
                                        "summary": {"type": "string"},
                                        "activities": {
                                            "type": "array",
                                            "items": {
                                                "type": "object",
                                                "properties": {
                                                    "time": {"type": "string"},
                                                    "title": {"type": "string"},
                                                    "description": {"type": "string"},
                                                    "destination_id": {
                                                        "type": ["integer", "null"]
                                                    },
                                                    "accommodation_id": {
                                                        "type": ["integer", "null"]
                                                    },
                                                    "transportation_id": {
                                                        "type": ["integer", "null"]
                                                    },
                                                    "estimated_cost": {"type": "string"},
                                                    "notes": {"type": ["string", "null"]},
                                                },
                                                "required": [
                                                    "time", "title", "description",
                                                    "destination_id", "accommodation_id",
                                                    "transportation_id", "estimated_cost",
                                                    "notes",
                                                ],
                                                "additionalProperties": False,
                                            },
                                        },
                                    },
                                    "required": [
                                        "day", "title", "summary", "activities",
                                    ],
                                    "additionalProperties": False,
                                },
                            },
                        },
                        "required": [
                            "option_number", "title", "summary",
                            "estimated_total_cost", "is_over_budget", "days",
                        ],
                        "additionalProperties": False,
                    },
                },
            },
            "required": ["options"],
            "additionalProperties": False,
        },
    },
}
