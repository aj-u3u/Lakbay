"""Stage reviewed OSM visitor candidates without publishing them.

Preview: python -m scripts.stage_osm_destination_candidates
Apply after migration: python -m scripts.stage_osm_destination_candidates --apply
"""

import argparse
import asyncio
import json
from pathlib import Path

from sqlalchemy import select

from app.db.base import import_model_modules
from app.db.session import get_sessionmaker
from app.features.destinations.models import DestinationCandidate


DEFAULT_INPUT = (
    Path(__file__).resolve().parents[1]
    / "docs/archive/davao_region_osm_catalog_triage_2026-11-04.jsonl"
)


def load_candidates(path: Path) -> list[dict]:
    candidates: dict[tuple[str, int], dict] = {}
    with path.open(encoding="utf-8") as source:
        for line_number, line in enumerate(source, start=1):
            row = json.loads(line)
            if row["review_decision"] != "visitor_candidate_review":
                continue
            identity = (row["osm_type"], int(row["osm_id"]))
            if identity not in candidates:
                if row["osm_type"] not in {"node", "way", "relation"}:
                    raise ValueError(f"Invalid OSM type on line {line_number}")
                if not (-90 <= row["latitude"] <= 90 and -180 <= row["longitude"] <= 180):
                    raise ValueError(f"Invalid coordinates on line {line_number}")
                if row["osm_url"] != f"https://www.openstreetmap.org/{identity[0]}/{identity[1]}":
                    raise ValueError(f"Invalid OSM URL on line {line_number}")
                candidates[identity] = row
    return list(candidates.values())


async def stage(path: Path) -> tuple[int, int]:
    import_model_modules()
    rows = load_candidates(path)
    async with get_sessionmaker()() as session:
        existing = await session.execute(
            select(DestinationCandidate.osm_type, DestinationCandidate.osm_id)
        )
        identities = set(existing.all())
        added = 0
        for row in rows:
            identity = (row["osm_type"], int(row["osm_id"]))
            if identity in identities:
                continue
            session.add(
                DestinationCandidate(
                    osm_type=identity[0],
                    osm_id=identity[1],
                    osm_url=row["osm_url"],
                    source_area=row["source_area"],
                    source_tag=row["source_tag"],
                    name=row["name"],
                    lat=row["latitude"],
                    lng=row["longitude"],
                    suggested_category=row["suggested_category"],
                    review_status="staged",
                    review_notes=(
                        "Review area assignment; OSM object appears in multiple area files."
                        if row["same_osm_id_in_multiple_areas"]
                        else "Possible existing catalog name match; check before publishing."
                        if row["exact_seed_name_match"]
                        else None
                    ),
                )
            )
            identities.add(identity)
            added += 1
        await session.commit()
        return added, len(rows) - added


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--apply", action="store_true", help="Write staged rows to the configured database")
    args = parser.parse_args()
    rows = load_candidates(args.input)
    if not args.apply:
        print(f"Preview: {len(rows)} unique candidates. No database changes made. Use --apply to stage.")
        return
    added, skipped = asyncio.run(stage(args.input))
    print(f"Staged {added} candidates; skipped {skipped} already present OSM identities.")


if __name__ == "__main__":
    main()
