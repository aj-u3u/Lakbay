"""Bounded, read-only Overpass lookups for the admin place review flow."""

import asyncio
from collections.abc import Callable
from time import monotonic

import httpx
from xml.etree import ElementTree

from app.core.config import get_settings
from app.core.exceptions import LakbayAPIError
from app.core.provider_usage import TTLCache


_cache = TTLCache(max_entries=256)
_TYPES = {"node", "way", "relation"}
# overpass-api.de rejects httpx's default User-Agent with HTTP 406.
_HEADERS = {"User-Agent": "Lakbay-admin-place-review/1.0"}
# Overpass answers these when its query queue is full and asks clients to back off.
_BUSY_STATUSES = {429, 502, 503, 504}
_RETRY_DELAYS_SECONDS = (1.0, 2.0)
_sleep = asyncio.sleep
# POSIX regex operators and QL quote characters. Each becomes "." (any character),
# so the query string needs no escape sequences that Overpass might read differently.
_UNSAFE_PATTERN_CHARS = frozenset('.[]{}()*+?^$|\\"\'')
# Overpass returns elements in ID order, not by relevance, so fetch enough for the
# service to sort by exact name and distance before trimming to the list it shows.
SEARCH_RESULT_CAP = 100


def name_pattern(name: str) -> str:
    """Return a case-insensitive Overpass name pattern containing no escapes."""
    return "".join(
        "." if char in _UNSAFE_PATTERN_CHARS or not char.isprintable() else char
        for char in name.strip()
    )


class OSMClient:
    def __init__(self, before_provider_call: Callable[[], None] | None = None) -> None:
        # Called only when a query misses the cache, so cached reviews cost no quota.
        self._before_provider_call = before_provider_call

    async def search(self, *, name: str, lat: float, lng: float, radius_m: int) -> list[dict]:
        query = (
            f'[out:json][timeout:10];'
            f'nwr(around:{radius_m},{lat:.7f},{lng:.7f})["name"~"{name_pattern(name)}",i];'
            f'out center {SEARCH_RESULT_CAP};'
        )
        return await self._query(query)

    async def get(self, osm_type: str, osm_id: int) -> dict | None:
        if osm_type not in _TYPES or osm_id < 1:
            raise ValueError("Invalid OSM identity")
        try:
            # The admin app times out after 20 seconds; leave time for the fallback.
            elements = await asyncio.wait_for(
                self._query(f"[out:json][timeout:10];{osm_type}({osm_id});out center;"),
                timeout=7,
            )
        except (LakbayAPIError, TimeoutError) as exc:
            if isinstance(exc, LakbayAPIError) and exc.code != "osm_unavailable":
                raise
            return await self._get_osm_api(osm_type, osm_id)
        return next(
            (row for row in elements if row.get("type") == osm_type and row.get("id") == osm_id),
            None,
        )

    async def _get_osm_api(self, osm_type: str, osm_id: int) -> dict | None:
        """Read one known object from OSM's official API if Overpass is busy."""
        suffix = "/full" if osm_type != "node" else ""
        url = f"https://api.openstreetmap.org/api/0.6/{osm_type}/{osm_id}{suffix}"
        try:
            async with httpx.AsyncClient(timeout=10, headers=_HEADERS) as client:
                response = await client.get(url)
        except httpx.RequestError as exc:
            raise LakbayAPIError(
                "OSM services are busy. Try again later or enter details manually.",
                code="osm_unavailable", status_code=503,
            ) from exc
        if response.status_code == 404:
            return None
        if response.status_code != 200 or len(response.content) > 1_000_000:
            raise LakbayAPIError(
                "OSM services are busy. Try again later or enter details manually.",
                code="osm_unavailable", status_code=503,
            )
        try:
            root = ElementTree.fromstring(response.content)
        except ElementTree.ParseError as exc:
            raise LakbayAPIError(
                "OSM returned an invalid response.", code="osm_invalid_response", status_code=502,
            ) from exc
        object_element = next(
            (item for item in root.findall(osm_type) if item.get("id") == str(osm_id)), None
        )
        if object_element is None:
            return None
        tags = {tag.get("k"): tag.get("v") for tag in object_element.findall("tag") if tag.get("k")}
        row: dict = {"type": osm_type, "id": osm_id, "tags": tags}
        try:
            if osm_type == "node":
                row.update(lat=float(object_element.get("lat")), lon=float(object_element.get("lon")))
            else:
                points = [(float(node.get("lat")), float(node.get("lon")))
                          for node in root.findall("node") if node.get("lat") and node.get("lon")]
                if points:
                    row["center"] = {
                        "lat": (min(p[0] for p in points) + max(p[0] for p in points)) / 2,
                        "lon": (min(p[1] for p in points) + max(p[1] for p in points)) / 2,
                    }
        except (TypeError, ValueError) as exc:
            raise LakbayAPIError(
                "OSM returned invalid coordinates.", code="osm_invalid_response", status_code=502,
            ) from exc
        return row

    async def _query(self, query: str) -> list[dict]:
        cached = _cache.get(query)
        if cached is not None:
            return cached
        if self._before_provider_call is not None:
            self._before_provider_call()
        response = await self._post(query)
        if response.status_code in _BUSY_STATUSES:
            raise LakbayAPIError(
                "OSM lookup is busy. Try again shortly or enter the details manually.",
                code="osm_unavailable",
                status_code=503,
            )
        if response.status_code != 200:
            raise LakbayAPIError(
                "OSM lookup is temporarily unavailable.", code="osm_unavailable", status_code=503
            )
        try:
            body = response.json()
        except ValueError as exc:
            raise LakbayAPIError(
                "OSM returned an invalid response.", code="osm_invalid_response", status_code=502
            ) from exc
        if not isinstance(body, dict) or not isinstance(body.get("elements"), list):
            raise LakbayAPIError(
                "OSM returned an invalid response.", code="osm_invalid_response", status_code=502
            )
        elements = [row for row in body["elements"] if isinstance(row, dict)]
        _cache.put(query, elements, ttl_seconds=300)
        return elements

    async def _post(self, query: str) -> httpx.Response:
        """POST once, retrying busy answers with backoff inside one timeout budget."""
        settings = get_settings()
        deadline = monotonic() + settings.overpass_request_timeout_seconds
        try:
            async with httpx.AsyncClient(
                timeout=settings.overpass_request_timeout_seconds, headers=_HEADERS
            ) as client:

                async def post() -> httpx.Response:
                    return await client.post(
                        settings.overpass_base_url,
                        data={"data": query},
                        timeout=max(1.0, deadline - monotonic()),
                    )

                for delay in _RETRY_DELAYS_SECONDS:
                    response = await post()
                    if (
                        response.status_code not in _BUSY_STATUSES
                        or monotonic() + delay + 1.0 >= deadline
                    ):
                        return response
                    await _sleep(delay)
                return await post()
        except httpx.RequestError as exc:
            raise LakbayAPIError(
                "OSM lookup timed out. Try again shortly or enter the details manually.",
                code="osm_unavailable", status_code=503,
            ) from exc
