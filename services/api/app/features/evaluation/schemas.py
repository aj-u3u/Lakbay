from datetime import datetime

from pydantic import BaseModel


class AIModelMetrics(BaseModel):
    model_role: str
    model_id: str
    attempts: int
    succeeded: int
    failed: int
    average_response_time_ms: float | None


class AIMetrics(BaseModel):
    attempts: int
    succeeded: int
    failed: int
    valid: int
    invalid: int
    fallback_used: int
    average_response_time_ms: float | None
    by_model: list[AIModelMetrics]


class RecommendationMetrics(BaseModel):
    preference_submissions: int
    catalog_views: int
    catalog_saves: int
    catalog_ratings: int
    catalog_itinerary_adds: int
    average_catalog_rating: float | None
    attribution_note: str


class CatalogMetrics(BaseModel):
    active_destinations: int
    route_ready_destinations: int
    unknown_cost_destinations: int


class EvaluationSummaryResponse(BaseModel):
    window_start: datetime
    generated_at: datetime
    ai: AIMetrics
    recommendations: RecommendationMetrics
    catalog: CatalogMetrics
