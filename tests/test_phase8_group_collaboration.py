from itertools import count


ADMIN_COUNTER = count(1)


DESTINATION = {
    "name": "Group Trip Stop",
    "description": "A destination for group collaboration tests.",
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
            "full_name": "Group Admin",
            "email": f"group-admin-{admin_index}@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )

    assert response.status_code == 201

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def create_destination(client) -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=admin_headers(client),
        json=DESTINATION,
    )

    assert response.status_code == 201

    return response.json()


def create_trip(client, headers: dict[str, str]) -> dict:
    destination = create_destination(client)
    response = client.post(
        "/api/v1/trips",
        headers=headers,
        json={
            "title": "Shared Davao Trip",
            "description": "A shared test trip.",
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


def test_trip_creator_becomes_owner_member(client) -> None:
    owner_headers = register_user(client, email="phase8-owner@example.com")

    trip = create_trip(client, owner_headers)
    members_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/members",
        headers=owner_headers,
    )

    assert trip["members"][0]["role"] == "owner"
    assert members_response.status_code == 200
    assert members_response.json()[0]["role"] == "owner"


def test_owner_can_add_member_and_member_can_view_shared_trip(client) -> None:
    owner_headers = register_user(client, email="owner-add@example.com")
    member_headers = register_user(client, email="shared-member@example.com")
    outsider_headers = register_user(client, email="not-shared@example.com")
    trip = create_trip(client, owner_headers)

    added_member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="shared-member@example.com",
    )
    member_trip_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=member_headers,
    )
    outsider_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=outsider_headers,
    )

    assert added_member["role"] == "member"
    assert member_trip_response.status_code == 200
    assert member_trip_response.json()["trip_id"] == trip["trip_id"]
    assert outsider_response.status_code == 404
    assert outsider_response.json()["error"]["code"] == "trip_not_found"


def test_duplicate_member_add_is_rejected(client) -> None:
    owner_headers = register_user(client, email="owner-duplicate@example.com")
    register_user(client, email="duplicate-member@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="duplicate-member@example.com",
    )

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/members",
        headers=owner_headers,
        json={"email": "duplicate-member@example.com", "role": "member"},
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "trip_member_already_exists"


def test_member_cannot_manage_members_but_organizer_can(client) -> None:
    owner_headers = register_user(client, email="owner-organizer@example.com")
    member_headers = register_user(client, email="plain-member@example.com")
    organizer_headers = register_user(client, email="organizer@example.com")
    register_user(client, email="new-member@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="plain-member@example.com",
    )
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="organizer@example.com",
        role="organizer",
    )

    member_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/members",
        headers=member_headers,
        json={"email": "new-member@example.com", "role": "member"},
    )
    organizer_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/members",
        headers=organizer_headers,
        json={"email": "new-member@example.com", "role": "member"},
    )

    assert member_response.status_code == 403
    assert member_response.json()["error"]["code"] == "trip_permission_denied"
    assert organizer_response.status_code == 201


def test_removed_member_loses_trip_access(client) -> None:
    owner_headers = register_user(client, email="owner-remove@example.com")
    member_headers = register_user(client, email="removed-member@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="removed-member@example.com",
    )

    remove_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/members/{member['trip_member_id']}",
        headers=owner_headers,
    )
    member_trip_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=member_headers,
    )

    assert remove_response.status_code == 200
    assert remove_response.json()["status"] == "removed"
    assert member_trip_response.status_code == 404


def test_only_owner_can_archive_shared_trip(client) -> None:
    owner_headers = register_user(client, email="owner-archive@example.com")
    member_headers = register_user(client, email="member-archive@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="member-archive@example.com",
    )

    member_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=member_headers,
    )
    owner_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=owner_headers,
    )

    assert member_response.status_code == 403
    assert member_response.json()["error"]["code"] == "trip_owner_required"
    assert owner_response.status_code == 200
    assert owner_response.json()["status"] == "archived"


def test_organizer_cannot_archive_shared_trip_with_status_update(client) -> None:
    owner_headers = register_user(client, email="owner-patch-archive@example.com")
    organizer_headers = register_user(client, email="organizer-patch-archive@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="organizer-patch-archive@example.com",
        role="organizer",
    )

    organizer_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=organizer_headers,
        json={"status": "archived"},
    )
    owner_check_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=owner_headers,
    )

    assert organizer_response.status_code == 403
    assert organizer_response.json()["error"]["code"] == "trip_owner_required"
    assert owner_check_response.status_code == 200
    assert owner_check_response.json()["status"] == "planned"


def test_member_can_create_assigned_task_and_complete_it(client) -> None:
    owner_headers = register_user(client, email="owner-task@example.com")
    member_headers = register_user(client, email="member-task@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="member-task@example.com",
    )

    create_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/tasks",
        headers=member_headers,
        json={
            "title": "Book lunch",
            "description": "Find a place near the route.",
            "assigned_trip_member_id": member["trip_member_id"],
            "due_date": "2026-10-10",
        },
    )
    task = create_response.json()
    list_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/tasks",
        headers=member_headers,
        params={"assigned_to_me": True},
    )
    complete_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/tasks/{task['trip_task_id']}",
        headers=member_headers,
        json={"status": "completed"},
    )

    assert create_response.status_code == 201
    assert task["status"] == "pending"
    assert list_response.status_code == 200
    assert list_response.json()[0]["trip_task_id"] == task["trip_task_id"]
    assert complete_response.status_code == 200
    assert complete_response.json()["status"] == "completed"
    assert complete_response.json()["completed_at"] is not None


def test_task_assignment_must_belong_to_same_trip(client) -> None:
    owner_headers = register_user(client, email="owner-assignment@example.com")
    register_user(client, email="other-trip-member@example.com")
    first_trip = create_trip(client, owner_headers)
    second_trip = create_trip(client, owner_headers)
    other_trip_member = add_member(
        client,
        headers=owner_headers,
        trip_id=second_trip["trip_id"],
        email="other-trip-member@example.com",
    )

    response = client.post(
        f"/api/v1/trips/{first_trip['trip_id']}/tasks",
        headers=owner_headers,
        json={
            "title": "Invalid assignment",
            "assigned_trip_member_id": other_trip_member["trip_member_id"],
        },
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "trip_member_not_found"


def test_task_status_filter_and_delete(client) -> None:
    owner_headers = register_user(client, email="owner-filter@example.com")
    trip = create_trip(client, owner_headers)
    pending_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/tasks",
        headers=owner_headers,
        json={"title": "Pending task"},
    )
    ongoing_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/tasks",
        headers=owner_headers,
        json={"title": "Ongoing task", "status": "ongoing"},
    )

    filter_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/tasks",
        headers=owner_headers,
        params={"status": "ongoing"},
    )
    delete_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/tasks/{pending_response.json()['trip_task_id']}",
        headers=owner_headers,
    )
    get_deleted_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/tasks/{pending_response.json()['trip_task_id']}",
        headers=owner_headers,
    )

    assert pending_response.status_code == 201
    assert ongoing_response.status_code == 201
    assert filter_response.status_code == 200
    assert [task["trip_task_id"] for task in filter_response.json()] == [
        ongoing_response.json()["trip_task_id"]
    ]
    assert delete_response.status_code == 204
    assert get_deleted_response.status_code == 404
