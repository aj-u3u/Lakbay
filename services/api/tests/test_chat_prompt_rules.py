from app.features.ai.schemas import AIChatRequest
from app.integrations.groq.prompts import CHAT_PROMPT_VERSION, build_chat_messages


def _system_prompt(**request) -> str:
    messages = build_chat_messages(request=AIChatRequest(message="Suggest a trip", **request))
    return messages[0]["content"]


def test_planning_chat_is_told_not_to_write_itineraries_in_chat():
    prompt = _system_prompt(planning_state={"origin": {"label": "Davao City"}})

    assert "Never write a day-by-day" in prompt
    assert "Generate itinerary" in prompt
    # The old instruction invited the model to draft itineraries in chat.
    assert "itinerary ideas" not in prompt
    assert "suggest destinations, budget tips" in prompt


def test_plain_chat_keeps_its_original_scope():
    prompt = _system_prompt()

    assert "itinerary ideas" in prompt
    assert "Never write a day-by-day" not in prompt


def test_the_prompt_version_changed_with_the_rules():
    assert CHAT_PROMPT_VERSION == "phase5_chat_v6_no_itinerary_in_chat"
