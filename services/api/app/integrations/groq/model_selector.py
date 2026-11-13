from dataclasses import dataclass

from app.core.config import Settings


@dataclass(frozen=True)
class ModelSelection:
    model_role: str
    model_id: str
    fallback_used: bool = False
    provider: str = "groq"


def select_primary_model(*, settings: Settings, model_role: str) -> ModelSelection | None:
    model_id = _model_id_for_role(settings=settings, model_role=model_role)

    if model_id:
        return ModelSelection(model_role=model_role, model_id=model_id)

    if model_role != "default" and settings.groq_model_default:
        return ModelSelection(model_role="default", model_id=settings.groq_model_default)

    return None


def select_fallback_models(
    *,
    settings: Settings,
    primary_model_id: str,
    for_itinerary: bool = False,
) -> list[ModelSelection]:
    """Ordered fallback chain, tried when the primary model fails or is rate limited.

    Limits are per model, so each entry has its own quota: first a second Groq
    model (GROQ_MODEL_FALLBACK), then every model listed in FALLBACK_LLM_MODEL
    (comma separated) on the second provider.
    """
    chain: list[ModelSelection] = []

    if (
        settings.groq_model_fallback
        and settings.groq_model_fallback != primary_model_id
        and (not for_itinerary or settings.groq_fallback_for_itineraries)
    ):
        chain.append(
            ModelSelection(
                model_role="fallback",
                model_id=settings.groq_model_fallback,
                fallback_used=True,
            )
        )

    if settings.fallback_llm_api_key and settings.fallback_llm_model:
        seen: set[str] = set()
        for model_id in settings.fallback_llm_model.split(","):
            model_id = model_id.strip()
            if not model_id or model_id in seen:
                continue
            seen.add(model_id)
            chain.append(
                ModelSelection(
                    model_role="fallback",
                    model_id=model_id,
                    fallback_used=True,
                    provider="fallback_llm",
                )
            )

    return chain


def select_fallback_model(
    *,
    settings: Settings,
    primary_model_id: str,
) -> ModelSelection | None:
    chain = select_fallback_models(settings=settings, primary_model_id=primary_model_id)
    return chain[0] if chain else None


def select_comparison_models(*, settings: Settings) -> list[ModelSelection]:
    comparison_models = [
        ("compare_a", settings.groq_model_compare_a),
        ("compare_b", settings.groq_model_compare_b),
        ("compare_c", settings.groq_model_compare_c),
    ]

    return [
        ModelSelection(model_role=role, model_id=model_id)
        for role, model_id in comparison_models
        if model_id
    ]


def _model_id_for_role(*, settings: Settings, model_role: str) -> str | None:
    if model_role == "default":
        return settings.groq_model_default

    if model_role == "fast":
        return settings.groq_model_fast

    if model_role == "quality":
        return settings.groq_model_quality

    return None
