from itertools import count

from app.integrations.storage.client import StorageUploadResult, get_storage_client


ADMIN_COUNTER = count(1)
JPEG_BYTES = b"\xff\xd8\xff\xe0" + b"lakbay-memory-image"


DESTINATION = {
    "name": "Memory Test Stop",
    "description": "A destination for memory tests.",
    "district": "Davao City",
    "location": "Davao City",
    "category": "park",
    "vibes": "relaxed",
    "activities": "walking",
    "lat": 7.0644,
    "lng": 125.6078,
    "estimated_cost": "100.00",
    "budget_class": "budget",
    "difficulty_level": "easy",
    "stay_duration_type": "short",
}


class FakeStorageClient:
    def __init__(self) -> None:
        self.calls: list[dict] = []

    async def upload_image(
        self,
        *,
        file_bytes: bytes,
        filename: str | None,
        content_type: str,
        folder_suffix: str | None = None,
    ) -> StorageUploadResult:
        self.calls.append(
            {
                "file_bytes": file_bytes,
                "filename": filename,
                "content_type": content_type,
                "folder_suffix": folder_suffix,
            }
        )

        return StorageUploadResult(
            image_url=f"https://res.cloudinary.com/demo/image/upload/{filename}",
            cloudinary_public_id=f"lakbay/{filename}",
            original_filename=filename,
            content_type=content_type,
            bytes=len(file_bytes),
            width=100,
            height=100,
            format="jpg",
            resource_type="image",
        )


def register_user(client, *, email: str) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": email.split("@")[0].replace("-", " ").title(),
            "email": email,
            "password": "password123",
            "confirm_password": "password123",
        },
    )

    assert response.status_code == 201

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def admin_headers(client) -> dict[str, str]:
    admin_index = next(ADMIN_COUNTER)
    response = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Memory Admin",
            "email": f"memory-admin-{admin_index}@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )

    assert response.status_code == 201

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def create_destination(client, *, name: str = "Memory Test Stop") -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=admin_headers(client),
        json={**DESTINATION, "name": name},
    )

    assert response.status_code == 201

    return response.json()


def create_trip(client, headers: dict[str, str]) -> dict:
    destination = create_destination(client)
    response = client.post(
        "/api/v1/trips",
        headers=headers,
        json={
            "title": "Memory Trip",
            "description": "A trip for memory tests.",
            "traveler_count": 2,
            "total_budget": "10000.00",
            "estimated_total_cost": "2500.00",
            "destination_ids": [destination["destination_id"]],
            "itinerary_days": [],
        },
    )

    assert response.status_code == 201

    return response.json()


def add_member(
    client,
    *,
    headers: dict[str, str],
    trip_id: int,
    email: str,
    role: str = "member",
) -> dict:
    response = client.post(
        f"/api/v1/trips/{trip_id}/members",
        headers=headers,
        json={"email": email, "role": role},
    )

    assert response.status_code == 201

    return response.json()


def create_memory(
    client,
    *,
    headers: dict[str, str],
    trip_id: int,
    destination_id: int | None = None,
) -> dict:
    response = client.post(
        f"/api/v1/trips/{trip_id}/memories",
        headers=headers,
        json={
            "image_url": "https://res.cloudinary.com/demo/image/upload/memory.jpg",
            "cloudinary_public_id": "lakbay/memory",
            "destination_id": destination_id,
            "caption": "A nice trip memory.",
            "location_tag": "Davao City",
            "taken_at": "2026-10-10T10:00:00Z",
        },
    )

    assert response.status_code == 201

    return response.json()


def override_storage(client, storage: FakeStorageClient) -> None:
    client.app.dependency_overrides[get_storage_client] = lambda: storage


def test_memories_require_authentication(client) -> None:
    response = client.get("/api/v1/trips/1/memories")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_active_member_can_upload_memory_image(client) -> None:
    owner_headers = register_user(client, email="memory-owner-upload@example.com")
    trip = create_trip(client, owner_headers)
    storage = FakeStorageClient()
    override_storage(client, storage)

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/memories/upload",
        headers=owner_headers,
        files={"file": ("memory.jpg", JPEG_BYTES, "image/jpeg")},
    )
    body = response.json()

    assert response.status_code == 200
    assert body["image_url"].endswith("/memory.jpg")
    assert body["cloudinary_public_id"] == "lakbay/memory.jpg"
    assert storage.calls[0]["folder_suffix"] == f"trips/{trip['trip_id']}/memories"
    assert storage.calls[0]["file_bytes"] == JPEG_BYTES


def test_upload_rejects_invalid_file_type(client) -> None:
    owner_headers = register_user(client, email="memory-owner-invalid-type@example.com")
    trip = create_trip(client, owner_headers)
    storage = FakeStorageClient()
    override_storage(client, storage)

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/memories/upload",
        headers=owner_headers,
        files={"file": ("memory.txt", b"not-image", "text/plain")},
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_image_type"
    assert storage.calls == []


def test_upload_rejects_fake_image_content(client) -> None:
    owner_headers = register_user(client, email="memory-owner-fake-image@example.com")
    trip = create_trip(client, owner_headers)
    storage = FakeStorageClient()
    override_storage(client, storage)

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/memories/upload",
        headers=owner_headers,
        files={"file": ("memory.jpg", b"not-really-an-image", "image/jpeg")},
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_image_content"
    assert storage.calls == []


def test_upload_rejects_oversized_image(client) -> None:
    owner_headers = register_user(client, email="memory-owner-large@example.com")
    trip = create_trip(client, owner_headers)
    storage = FakeStorageClient()
    override_storage(client, storage)

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/memories/upload",
        headers=owner_headers,
        files={"file": ("large.jpg", b"x" * 5_242_881, "image/jpeg")},
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "upload_too_large"
    assert storage.calls == []


def test_member_can_create_and_list_memory(client) -> None:
    owner_headers = register_user(client, email="memory-owner-create@example.com")
    member_headers = register_user(client, email="memory-member-create@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="memory-member-create@example.com",
    )
    destination_id = trip["destinations"][0]["destination_id"]

    memory = create_memory(
        client,
        headers=member_headers,
        trip_id=trip["trip_id"],
        destination_id=destination_id,
    )
    list_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/memories",
        headers=owner_headers,
    )

    assert memory["uploaded_by_email"] == "memory-member-create@example.com"
    assert memory["destination_id"] == destination_id
    assert memory["destination_name"] == "Memory Test Stop"
    assert list_response.status_code == 200
    assert list_response.json()[0]["trip_memory_id"] == memory["trip_memory_id"]


def test_memory_destination_must_belong_to_trip(client) -> None:
    owner_headers = register_user(client, email="memory-owner-destination@example.com")
    trip = create_trip(client, owner_headers)
    other_destination = create_destination(client, name="Other Memory Stop")

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/memories",
        headers=owner_headers,
        json={
            "image_url": "https://res.cloudinary.com/demo/image/upload/memory.jpg",
            "destination_id": other_destination["destination_id"],
        },
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "trip_memory_destination_mismatch"


def test_memory_image_url_must_be_cloudinary(client) -> None:
    owner_headers = register_user(client, email="memory-owner-url@example.com")
    trip = create_trip(client, owner_headers)

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/memories",
        headers=owner_headers,
        json={
            "image_url": "https://example.com/not-cloudinary.jpg",
            "caption": "This should not be accepted.",
        },
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "invalid_memory_image_url"


def test_outsider_and_removed_member_cannot_access_memories(client) -> None:
    owner_headers = register_user(client, email="memory-owner-access@example.com")
    member_headers = register_user(client, email="memory-member-access@example.com")
    outsider_headers = register_user(client, email="memory-outsider-access@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="memory-member-access@example.com",
    )
    create_memory(client, headers=owner_headers, trip_id=trip["trip_id"])

    outsider_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/memories",
        headers=outsider_headers,
    )
    remove_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/members/{member['trip_member_id']}",
        headers=owner_headers,
    )
    removed_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/memories",
        headers=member_headers,
    )

    assert outsider_response.status_code == 404
    assert outsider_response.json()["error"]["code"] == "trip_not_found"
    assert remove_response.status_code == 200
    assert removed_response.status_code == 404
    assert removed_response.json()["error"]["code"] == "trip_not_found"


def test_uploader_owner_and_organizer_memory_permissions(client) -> None:
    owner_headers = register_user(client, email="memory-owner-permission@example.com")
    uploader_headers = register_user(client, email="memory-uploader-permission@example.com")
    other_headers = register_user(client, email="memory-other-permission@example.com")
    organizer_headers = register_user(client, email="memory-organizer-permission@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="memory-uploader-permission@example.com",
    )
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="memory-other-permission@example.com",
    )
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="memory-organizer-permission@example.com",
        role="organizer",
    )
    memory = create_memory(
        client,
        headers=uploader_headers,
        trip_id=trip["trip_id"],
    )

    denied_update = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/memories/{memory['trip_memory_id']}",
        headers=other_headers,
        json={"caption": "Nope"},
    )
    uploader_update = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/memories/{memory['trip_memory_id']}",
        headers=uploader_headers,
        json={"caption": "Updated caption"},
    )
    organizer_delete = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/memories/{memory['trip_memory_id']}",
        headers=organizer_headers,
    )
    other_deleted_list = client.get(
        f"/api/v1/trips/{trip['trip_id']}/memories?include_deleted=true",
        headers=other_headers,
    )
    owner_deleted_list = client.get(
        f"/api/v1/trips/{trip['trip_id']}/memories?include_deleted=true",
        headers=owner_headers,
    )
    owner_list = client.get(
        f"/api/v1/trips/{trip['trip_id']}/memories",
        headers=owner_headers,
    )

    assert denied_update.status_code == 403
    assert denied_update.json()["error"]["code"] == "trip_memory_permission_denied"
    assert uploader_update.status_code == 200
    assert uploader_update.json()["caption"] == "Updated caption"
    assert organizer_delete.status_code == 200
    assert organizer_delete.json()["status"] == "deleted"
    assert other_deleted_list.status_code == 403
    assert other_deleted_list.json()["error"]["code"] == "deleted_memories_permission_denied"
    assert owner_deleted_list.status_code == 200
    assert owner_deleted_list.json()[0]["status"] == "deleted"
    assert owner_list.status_code == 200
    assert owner_list.json() == []


def test_archived_trip_rejects_memory_writes(client) -> None:
    owner_headers = register_user(client, email="memory-owner-archived@example.com")
    trip = create_trip(client, owner_headers)
    memory = create_memory(client, headers=owner_headers, trip_id=trip["trip_id"])
    archive_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/archive",
        headers=owner_headers,
    )
    storage = FakeStorageClient()
    override_storage(client, storage)

    upload_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/memories/upload",
        headers=owner_headers,
        files={"file": ("memory.jpg", b"image-bytes", "image/jpeg")},
    )
    create_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/memories",
        headers=owner_headers,
        json={"image_url": "https://res.cloudinary.com/demo/image/upload/new.jpg"},
    )
    update_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/memories/{memory['trip_memory_id']}",
        headers=owner_headers,
        json={"caption": "Late update"},
    )
    delete_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/memories/{memory['trip_memory_id']}",
        headers=owner_headers,
    )

    assert archive_response.status_code == 200
    assert upload_response.status_code == 400
    assert upload_response.json()["error"]["code"] == "trip_archived_read_only"
    assert create_response.status_code == 400
    assert create_response.json()["error"]["code"] == "trip_archived_read_only"
    assert update_response.status_code == 400
    assert update_response.json()["error"]["code"] == "trip_archived_read_only"
    assert delete_response.status_code == 400
    assert delete_response.json()["error"]["code"] == "trip_archived_read_only"
    assert storage.calls == []
