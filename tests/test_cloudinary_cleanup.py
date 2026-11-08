import asyncio
from types import SimpleNamespace

import cloudinary.uploader
import pytest

from app.core.config import Settings
from app.integrations.storage.client import CloudinaryStorageClient
from scripts.cleanup_cloudinary_memory import inspect_candidate, purge_candidate


class FakeSession:
    def __init__(self, memory, active_count=0):
        self.memory = memory
        self.active_count = active_count

    async def get(self, model, memory_id):
        return self.memory

    async def scalar(self, statement):
        return self.active_count


class FakeStorage:
    def __init__(self):
        self.deleted = []

    async def delete_image(self, public_id):
        self.deleted.append(public_id)
        return "ok"


def _memory(status="deleted", public_id="lakbay/trips/7/memories/photo"):
    return SimpleNamespace(
        trip_memory_id=12,
        trip_id=7,
        status=status,
        cloudinary_public_id=public_id,
    )


def test_cleanup_requires_deleted_owned_unreferenced_asset():
    settings = Settings(_env_file=None, cloudinary_upload_folder="lakbay")
    candidate = asyncio.run(inspect_candidate(FakeSession(_memory()), 12, settings))
    assert candidate.public_id == "lakbay/trips/7/memories/photo"

    for session in (
        FakeSession(_memory(status="active")),
        FakeSession(_memory(public_id="unrelated/photo")),
        FakeSession(_memory(), active_count=1),
    ):
        with pytest.raises(ValueError):
            asyncio.run(inspect_candidate(session, 12, settings))


def test_purge_requires_exact_confirmation_before_storage_call():
    settings = Settings(_env_file=None, cloudinary_upload_folder="lakbay")
    storage = FakeStorage()
    session = FakeSession(_memory())
    with pytest.raises(ValueError):
        asyncio.run(purge_candidate(
            session, 12, settings,
            confirm_public_id="wrong", storage=storage,
        ))
    assert storage.deleted == []

    result = asyncio.run(purge_candidate(
        session, 12, settings,
        confirm_public_id="lakbay/trips/7/memories/photo", storage=storage,
    ))
    assert result == "ok"
    assert storage.deleted == ["lakbay/trips/7/memories/photo"]


def test_storage_destroy_uses_image_type_and_cdn_invalidation(monkeypatch):
    calls = []

    def fake_destroy(public_id, **kwargs):
        calls.append((public_id, kwargs))
        return {"result": "ok"}

    monkeypatch.setattr(cloudinary.uploader, "destroy", fake_destroy)
    settings = Settings(
        _env_file=None,
        cloudinary_cloud_name="demo",
        cloudinary_api_key="test-key",
        cloudinary_api_secret="test-secret",
    )
    result = asyncio.run(CloudinaryStorageClient(settings).delete_image("lakbay/test"))
    assert result == "ok"
    assert calls == [("lakbay/test", {"resource_type": "image", "invalidate": True})]
