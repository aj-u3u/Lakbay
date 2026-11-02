from fastapi import APIRouter

from app.features.accommodations.router import (
    destination_router as destination_accommodations_router,
)
from app.features.accommodations.router import router as accommodations_router
from app.features.ai.router import router as ai_router
from app.features.auth.router import router as auth_router
from app.features.budgets.router import router as budgets_router
from app.features.destinations.router import router as destinations_router
from app.features.expenses.router import router as expenses_router
from app.features.evaluation.router import router as evaluation_router
from app.features.geo_analytics.router import router as geo_analytics_router
from app.features.health.router import router as health_router
from app.features.memories.router import router as memories_router
from app.features.notifications.router import router as notifications_router
from app.features.planning.router import router as planning_router
from app.features.recommendations.router import (
    destination_router as destination_recommendations_router,
)
from app.features.recommendations.router import router as recommendations_router
from app.features.reports.router import router as reports_router
from app.features.reviews.router import router as reviews_router
from app.features.routes.router import router as routes_router
from app.features.trips.router import router as trips_router
from app.features.transportations.router import (
    destination_router as destination_transportations_router,
)
from app.features.transportations.router import router as transportations_router
from app.features.users.router import router as users_router
from app.features.weather.router import destination_router as destination_weather_router
from app.features.weather.router import router as weather_router


api_router = APIRouter()
api_router.include_router(auth_router)
api_router.include_router(ai_router)
api_router.include_router(destinations_router)
api_router.include_router(destination_accommodations_router)
api_router.include_router(accommodations_router)
api_router.include_router(destination_transportations_router)
api_router.include_router(transportations_router)
api_router.include_router(recommendations_router)
api_router.include_router(destination_recommendations_router)
api_router.include_router(budgets_router)
api_router.include_router(geo_analytics_router)
api_router.include_router(planning_router)
api_router.include_router(routes_router)
api_router.include_router(weather_router)
api_router.include_router(destination_weather_router)
api_router.include_router(trips_router)
api_router.include_router(expenses_router)
api_router.include_router(evaluation_router)
api_router.include_router(memories_router)
api_router.include_router(reports_router)
api_router.include_router(reviews_router)
api_router.include_router(notifications_router)
api_router.include_router(health_router)
api_router.include_router(users_router)
