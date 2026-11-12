from sqlalchemy.ext.asyncio import AsyncSession

from app.features.destinations.catalog_selection import CatalogSelectionQueries


class RouteRepository(CatalogSelectionQueries):
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
