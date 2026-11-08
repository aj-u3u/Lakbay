"""Preview or explicitly purge one soft-deleted Lakbay memory image."""

import argparse
import asyncio
import sys
from dataclasses import dataclass
from pathlib import Path

from sqlalchemy import func, select

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import Settings, get_settings  # noqa: E402
from app.db.session import get_sessionmaker  # noqa: E402
from app.features.memories.models import TripMemory  # noqa: E402
from app.integrations.storage.client import CloudinaryStorageClient  # noqa: E402


@dataclass(frozen=True)
class CleanupCandidate:
    memory_id: int
    trip_id: int
    public_id: str


async def inspect_candidate(session, memory_id: int, settings: Settings) -> CleanupCandidate:
    memory = await session.get(TripMemory, memory_id)
    if memory is None or memory.status != "deleted" or not memory.cloudinary_public_id:
        raise ValueError("Memory must exist, be soft-deleted, and have a Cloudinary public ID.")
    folder = settings.cloudinary_upload_folder.strip("/") or "lakbay"
    expected_prefix = f"{folder}/trips/{memory.trip_id}/memories/"
    if not memory.cloudinary_public_id.startswith(expected_prefix):
        raise ValueError("Public ID is outside this trip's Lakbay upload folder.")
    active_count = await session.scalar(
        select(func.count(TripMemory.trip_memory_id)).where(
            TripMemory.cloudinary_public_id == memory.cloudinary_public_id,
            TripMemory.status == "active",
        )
    )
    if active_count:
        raise ValueError("An active memory still references this Cloudinary asset.")
    return CleanupCandidate(
        memory_id=memory.trip_memory_id,
        trip_id=memory.trip_id,
        public_id=memory.cloudinary_public_id,
    )


async def purge_candidate(
    session,
    memory_id: int,
    settings: Settings,
    *,
    confirm_public_id: str,
    storage: CloudinaryStorageClient,
) -> str:
    candidate = await inspect_candidate(session, memory_id, settings)
    if confirm_public_id != candidate.public_id:
        raise ValueError("Confirmation must exactly match the candidate public ID.")
    return await storage.delete_image(candidate.public_id)


async def _run(args) -> int:
    settings = get_settings()
    sessionmaker = get_sessionmaker()
    async with sessionmaker() as session:
        candidate = await inspect_candidate(session, args.memory_id, settings)
        print(f"Deleted memory {candidate.memory_id} in trip {candidate.trip_id}")
        print(f"Cloudinary public ID: {candidate.public_id}")
        if not args.purge:
            print("Preview only. No Cloudinary asset was deleted.")
            return 0
        result = await purge_candidate(
            session,
            args.memory_id,
            settings,
            confirm_public_id=args.confirm_public_id,
            storage=CloudinaryStorageClient(settings),
        )
        print(f"Cloudinary deletion result: {result}")
        return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--memory-id", required=True, type=int)
    parser.add_argument("--purge", action="store_true", help="Delete this one Cloudinary image")
    parser.add_argument("--confirm-public-id", help="Required exact ID when purging")
    args = parser.parse_args()
    if args.purge and not args.confirm_public_id:
        parser.error("--purge requires --confirm-public-id")
    try:
        return asyncio.run(_run(args))
    except ValueError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    except Exception as exc:
        print(f"Cleanup failed ({type(exc).__name__}).", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
