from itertools import count

from fastapi.testclient import TestClient

ADMIN_COUNTER = count(1)


DESTINATION = {
    "name": "Notification Test Stop",
    "description": "A destination for notification tests.",
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
            "full_name": "Notification Admin",
            "email": f"notification-admin-{admin_index}@example.com",
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
            "title": "Notification Trip",
            "description": "A trip for notification tests.",
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


def create_expense(
    client,
    *,
    headers: dict[str, str],
    trip_id: int,
    paid_by_trip_member_id: int,
) -> dict:
    response = client.post(
        f"/api/v1/trips/{trip_id}/expenses",
        headers=headers,
        json={
            "title": "Shared dinner",
            "category": "meals",
            "amount": "90.00",
            "paid_by_trip_member_id": paid_by_trip_member_id,
            "expense_date": "2026-10-10",
        },
    )

    assert response.status_code == 201

    return response.json()


def test_notifications_require_authentication(client) -> None:
    response = client.get("/api/v1/notifications")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_added_trip_member_receives_scoped_notification(client) -> None:
    owner_headers = register_user(client, email="notification-owner-add@example.com")
    member_headers = register_user(client, email="notification-member-add@example.com")
    outsider_headers = register_user(client, email="notification-outsider-add@example.com")
    trip = create_trip(client, owner_headers)

    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="notification-member-add@example.com",
    )

    member_response = client.get("/api/v1/notifications", headers=member_headers)
    owner_response = client.get("/api/v1/notifications", headers=owner_headers)
    unread_response = client.get(
        "/api/v1/notifications/unread-count",
        headers=member_headers,
    )
    notification = member_response.json()[0]
    outsider_read_response = client.patch(
        f"/api/v1/notifications/{notification['notification_id']}/read",
        headers=outsider_headers,
    )

    assert member_response.status_code == 200
    assert notification["event_type"] == "trip_member_added"
    assert notification["trip_id"] == trip["trip_id"]
    assert notification["actor_full_name"] == "Notification Owner Add"
    assert notification["recipient_user_id"] != notification["actor_user_id"]
    assert notification["is_read"] is False
    assert notification["metadata"]["role"] == "member"
    assert owner_response.json() == []
    assert unread_response.json()["unread_count"] == 1
    assert outsider_read_response.status_code == 404
    assert outsider_read_response.json()["error"]["code"] == "notification_not_found"


def test_task_assignment_read_and_delete_flow(client) -> None:
    owner_headers = register_user(client, email="notification-owner-task@example.com")
    member_headers = register_user(client, email="notification-member-task@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="notification-member-task@example.com",
    )
    read_all_existing = client.patch(
        "/api/v1/notifications/read-all",
        headers=member_headers,
    )

    task_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/tasks",
        headers=owner_headers,
        json={
            "title": "Book van rental",
            "assigned_trip_member_id": member["trip_member_id"],
        },
    )
    list_response = client.get(
        "/api/v1/notifications",
        headers=member_headers,
        params={"event_type": "task_assigned"},
    )
    notification = list_response.json()[0]
    unread_response = client.get(
        "/api/v1/notifications/unread-count",
        headers=member_headers,
    )
    read_response = client.patch(
        f"/api/v1/notifications/{notification['notification_id']}/read",
        headers=member_headers,
    )
    delete_response = client.delete(
        f"/api/v1/notifications/{notification['notification_id']}",
        headers=member_headers,
    )
    after_delete_response = client.get(
        "/api/v1/notifications",
        headers=member_headers,
        params={"event_type": "task_assigned"},
    )

    assert read_all_existing.status_code == 200
    assert task_response.status_code == 201
    assert list_response.status_code == 200
    assert notification["entity_type"] == "trip_task"
    assert notification["entity_id"] == task_response.json()["trip_task_id"]
    assert notification["metadata"]["task_title"] == "Book van rental"
    assert unread_response.json()["unread_count"] == 1
    assert read_response.status_code == 200
    assert read_response.json()["is_read"] is True
    assert read_response.json()["read_at"] is not None
    assert delete_response.status_code == 200
    assert delete_response.json()["status"] == "deleted"
    assert after_delete_response.json() == []


def test_removed_member_notification_uses_snapshot_display_fields(client) -> None:
    owner_headers = register_user(client, email="notification-owner-snapshot@example.com")
    member_headers = register_user(client, email="notification-member-snapshot@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="notification-member-snapshot@example.com",
    )

    remove_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/members/{member['trip_member_id']}",
        headers=owner_headers,
    )
    rename_trip_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=owner_headers,
        json={"title": "Renamed Private Trip"},
    )
    rename_actor_response = client.patch(
        "/api/v1/users/me",
        headers=owner_headers,
        json={"full_name": "Renamed Owner"},
    )
    notifications_response = client.get(
        "/api/v1/notifications",
        headers=member_headers,
        params={"event_type": "trip_member_added"},
    )
    notification = notifications_response.json()[0]

    assert remove_response.status_code == 200
    assert rename_trip_response.status_code == 200
    assert rename_actor_response.status_code == 200
    assert notifications_response.status_code == 200
    assert notification["trip_title"] == "Notification Trip"
    assert notification["actor_full_name"] == "Notification Owner Snapshot"
    assert notification["metadata"]["trip_title"] == "Notification Trip"
    assert notification["metadata"]["actor_full_name"] == "Notification Owner Snapshot"


def test_expense_events_notify_members_except_actor(client) -> None:
    owner_headers = register_user(client, email="notification-owner-expense@example.com")
    member_headers = register_user(client, email="notification-member-expense@example.com")
    third_headers = register_user(client, email="notification-third-expense@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="notification-member-expense@example.com",
    )
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="notification-third-expense@example.com",
    )
    client.patch("/api/v1/notifications/read-all", headers=member_headers)
    client.patch("/api/v1/notifications/read-all", headers=third_headers)

    expense = create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=trip["members"][0]["trip_member_id"],
    )
    update_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=owner_headers,
        json={"amount": "120.00"},
    )
    void_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=owner_headers,
    )

    owner_notifications = client.get(
        "/api/v1/notifications",
        headers=owner_headers,
    )
    member_notifications = client.get(
        "/api/v1/notifications",
        headers=member_headers,
        params={"trip_id": trip["trip_id"], "unread_only": True},
    )
    third_created_notifications = client.get(
        "/api/v1/notifications",
        headers=third_headers,
        params={"event_type": "expense_created"},
    )
    member_event_types = {
        notification["event_type"] for notification in member_notifications.json()
    }

    assert update_response.status_code == 200
    assert void_response.status_code == 200
    assert owner_notifications.json() == []
    assert member_event_types == {
        "expense_created",
        "expense_updated",
        "expense_voided",
    }
    assert third_created_notifications.json()[0]["metadata"]["amount"] == "90.00"


def test_trip_and_route_updates_create_notifications(client) -> None:
    owner_headers = register_user(client, email="notification-owner-route@example.com")
    member_headers = register_user(client, email="notification-member-route@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="notification-member-route@example.com",
    )
    client.patch("/api/v1/notifications/read-all", headers=member_headers)
    destination = trip["destinations"][0]

    update_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=owner_headers,
        json={"title": "Updated Notification Trip"},
    )
    route_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=owner_headers,
        json={
            "travel_mode": "driving",
            "route_provider": "haversine",
            "is_estimated": True,
            "total_distance_km": "0.00",
            "total_duration_minutes": 0,
            "stops": [
                {
                    "order": 1,
                    "destination_id": destination["destination_id"],
                    "name": destination["name"],
                    "lat": DESTINATION["lat"],
                    "lng": DESTINATION["lng"],
                    "is_origin": False,
                }
            ],
            "legs": [],
            "warnings": [],
        },
    )

    notifications_response = client.get(
        "/api/v1/notifications",
        headers=member_headers,
        params={"trip_id": trip["trip_id"], "unread_only": True},
    )
    event_types = {
        notification["event_type"]
        for notification in notifications_response.json()
    }

    assert update_response.status_code == 200
    assert route_response.status_code == 200
    assert event_types == {"trip_updated", "trip_route_updated"}


def test_two_account_collaboration_sync_and_outsider_denial(client) -> None:
    owner_headers = register_user(client, email="sync-owner@example.com")
    member_headers = register_user(client, email="sync-member@example.com")
    outsider_headers = register_user(client, email="sync-outsider@example.com")
    trip = create_trip(client, owner_headers)
    trip_id = trip["trip_id"]
    owner_member_id = trip["members"][0]["trip_member_id"]

    with TestClient(client.app) as second_device:
        member = add_member(
            client,
            headers=owner_headers,
            trip_id=trip_id,
            email="sync-member@example.com",
        )
        member_trips = second_device.get("/api/v1/trips", headers=member_headers)
        assert member_trips.status_code == 200
        assert trip_id in {item["trip_id"] for item in member_trips.json()}

        task = second_device.post(
            f"/api/v1/trips/{trip_id}/tasks",
            headers=member_headers,
            json={"title": "Reserve transport", "assigned_trip_member_id": owner_member_id},
        )
        assert task.status_code == 201
        owner_tasks = client.get(f"/api/v1/trips/{trip_id}/tasks", headers=owner_headers)
        assert owner_tasks.status_code == 200
        assert owner_tasks.json()[0]["trip_task_id"] == task.json()["trip_task_id"]

        role_update = client.patch(
            f"/api/v1/trips/{trip_id}/members/{member['trip_member_id']}",
            headers=owner_headers,
            json={"role": "organizer"},
        )
        assert role_update.status_code == 200
        member_view = second_device.get(
            f"/api/v1/trips/{trip_id}/members", headers=member_headers
        )
        assert member_view.status_code == 200
        assert any(
            row["trip_member_id"] == member["trip_member_id"]
            and row["role"] == "organizer"
            for row in member_view.json()
        )

        expense = create_expense(
            client,
            headers=owner_headers,
            trip_id=trip_id,
            paid_by_trip_member_id=owner_member_id,
        )
        member_expenses = second_device.get(
            f"/api/v1/trips/{trip_id}/expenses", headers=member_headers
        )
        assert member_expenses.status_code == 200
        assert member_expenses.json()[0]["trip_expense_id"] == expense["trip_expense_id"]
        assert sorted(
            split["share_amount"] for split in member_expenses.json()[0]["splits"]
        ) == ["45.00", "45.00"]

        member_notifications = second_device.get(
            "/api/v1/notifications", headers=member_headers
        )
        owner_notifications = client.get(
            "/api/v1/notifications", headers=owner_headers
        )
        assert member_notifications.status_code == 200
        assert {item["event_type"] for item in member_notifications.json()} >= {
            "trip_member_added", "expense_created"
        }
        assert any(
            item["event_type"] == "task_assigned"
            for item in owner_notifications.json()
        )

        outsider_read = second_device.get(
            f"/api/v1/trips/{trip_id}", headers=outsider_headers
        )
        outsider_task = second_device.post(
            f"/api/v1/trips/{trip_id}/tasks",
            headers=outsider_headers,
            json={"title": "Unauthorized task"},
        )
        outsider_expenses = second_device.get(
            f"/api/v1/trips/{trip_id}/expenses", headers=outsider_headers
        )
        assert outsider_read.status_code == 404
        assert outsider_task.status_code == 404
        assert outsider_expenses.status_code == 404
        remaining_tasks = client.get(
            f"/api/v1/trips/{trip_id}/tasks", headers=owner_headers
        )
        assert remaining_tasks.status_code == 200
        assert len(remaining_tasks.json()) == 1
