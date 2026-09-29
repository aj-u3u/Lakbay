DESTINATION_A = {
    "name": "Trip Stop A",
    "description": "A trip test destination.",
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
DESTINATION_B = {
    **DESTINATION_A,
    "name": "Trip Stop B",
    "lat": 7.0994,
    "lng": 125.6197,
}
DESTINATION_C = {
    **DESTINATION_A,
    "name": "Trip Stop C",
    "lat": 7.1422,
    "lng": 125.6617,
}


def admin_headers(client) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Trip Admin",
            "email": "trip-admin@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def user_headers(client, *, email: str = "trip-user@example.com") -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Trip User",
            "email": email,
            "password": "password123",
            "confirm_password": "password123",
        },
    )

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def create_destination(client, headers: dict[str, str], payload: dict) -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=headers,
        json=payload,
    )

    assert response.status_code == 201

    return response.json()


def create_destinations(client) -> tuple[dict, dict]:
    headers = admin_headers(client)

    return (
        create_destination(client, headers, DESTINATION_A),
        create_destination(client, headers, DESTINATION_B),
    )


def create_three_destinations(client) -> tuple[dict, dict, dict]:
    headers = admin_headers(client)

    return (
        create_destination(client, headers, DESTINATION_A),
        create_destination(client, headers, DESTINATION_B),
        create_destination(client, headers, DESTINATION_C),
    )


def trip_payload(destination_ids: list[int], **overrides) -> dict:
    payload = {
        "title": "Davao Weekend Trip",
        "description": "A saved trip for testing.",
        "start_date": "2026-10-10",
        "end_date": "2026-10-11",
        "traveler_count": 2,
        "total_budget": "10000.00",
        "estimated_total_cost": "3500.00",
        "destination_ids": destination_ids,
        "notes": "Keep the pace relaxed.",
        "itinerary_days": [
            {
                "day_number": 1,
                "title": "Arrival",
                "summary": "Start with the first stop.",
                "activities": [
                    {
                        "activity_order": 1,
                        "time": "09:00",
                        "title": "Visit first stop",
                        "description": "Explore the selected destination.",
                        "destination_id": destination_ids[0],
                        "estimated_cost": "500.00",
                        "notes": "Bring water.",
                    }
                ],
            }
        ],
    }
    payload.update(overrides)

    return payload


def create_trip(client, headers: dict[str, str], destination_ids: list[int]) -> dict:
    response = client.post(
        "/api/v1/trips",
        headers=headers,
        json=trip_payload(destination_ids),
    )

    assert response.status_code == 201

    return response.json()


def route_payload(destination_id: int) -> dict:
    return {
        "travel_mode": "driving",
        "route_provider": "osrm",
        "is_estimated": False,
        "total_distance_km": "12.50",
        "total_duration_minutes": 30,
        "stops": [
            {
                "order": 1,
                "destination_id": destination_id,
                "name": "Trip Stop A",
                "lat": 7.0644,
                "lng": 125.6078,
                "is_origin": False,
            }
        ],
        "legs": [],
        "warnings": [],
    }


def two_stop_route_payload(from_destination_id: int, to_destination_id: int) -> dict:
    return {
        "travel_mode": "driving",
        "route_provider": "osrm",
        "is_estimated": False,
        "total_distance_km": "18.75",
        "total_duration_minutes": 42,
        "stops": [
            {
                "order": 1,
                "destination_id": from_destination_id,
                "name": "Trip Stop A",
                "lat": 7.0644,
                "lng": 125.6078,
                "is_origin": False,
            },
            {
                "order": 2,
                "destination_id": to_destination_id,
                "name": "Trip Stop B",
                "lat": 7.0994,
                "lng": 125.6197,
                "is_origin": False,
            },
        ],
        "legs": [
            {
                "order": 1,
                "from_destination_id": from_destination_id,
                "to_destination_id": to_destination_id,
                "from_name": "Trip Stop A",
                "to_name": "Trip Stop B",
                "distance_km": "18.75",
                "duration_minutes": 42,
                "is_estimated": False,
            }
        ],
        "warnings": [],
    }


def test_create_trip_requires_authentication(client) -> None:
    response = client.post(
        "/api/v1/trips",
        json=trip_payload([1]),
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_user_can_create_and_get_trip(client) -> None:
    destination_a, destination_b = create_destinations(client)
    headers = user_headers(client)

    create_response = client.post(
        "/api/v1/trips",
        headers=headers,
        json=trip_payload(
            [destination_a["destination_id"], destination_b["destination_id"]],
        ),
    )

    assert create_response.status_code == 201
    body = create_response.json()
    assert body["title"] == "Davao Weekend Trip"
    assert body["status"] == "planned"
    assert [item["destination_id"] for item in body["destinations"]] == [
        destination_a["destination_id"],
        destination_b["destination_id"],
    ]
    assert body["itinerary_days"][0]["activities"][0]["title"] == "Visit first stop"

    get_response = client.get(
        f"/api/v1/trips/{body['trip_id']}",
        headers=headers,
    )

    assert get_response.status_code == 200
    assert get_response.json()["trip_id"] == body["trip_id"]


def test_user_only_lists_own_trips(client) -> None:
    destination_a, _ = create_destinations(client)
    user_one = user_headers(client, email="trip-owner-one@example.com")
    user_two = user_headers(client, email="trip-owner-two@example.com")
    trip_one = create_trip(client, user_one, [destination_a["destination_id"]])
    create_trip(client, user_two, [destination_a["destination_id"]])

    response = client.get("/api/v1/trips", headers=user_one)

    assert response.status_code == 200
    assert [trip["trip_id"] for trip in response.json()] == [trip_one["trip_id"]]


def test_user_cannot_access_another_users_trip(client) -> None:
    destination_a, _ = create_destinations(client)
    owner = user_headers(client, email="owner@example.com")
    other_user = user_headers(client, email="other@example.com")
    trip = create_trip(client, owner, [destination_a["destination_id"]])

    response = client.get(f"/api/v1/trips/{trip['trip_id']}", headers=other_user)

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "trip_not_found"


def test_create_trip_rejects_missing_destination(client) -> None:
    headers = user_headers(client)

    response = client.post(
        "/api/v1/trips",
        headers=headers,
        json=trip_payload([999]),
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "destination_not_found"


def test_create_trip_rejects_duplicate_destinations(client) -> None:
    destination_a, _ = create_destinations(client)

    response = client.post(
        "/api/v1/trips",
        headers=user_headers(client),
        json=trip_payload(
            [destination_a["destination_id"], destination_a["destination_id"]],
        ),
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_create_trip_rejects_activity_destination_outside_trip(client) -> None:
    destination_a, destination_b = create_destinations(client)
    payload = trip_payload([destination_a["destination_id"]])
    payload["itinerary_days"][0]["activities"][0]["destination_id"] = (
        destination_b["destination_id"]
    )

    response = client.post(
        "/api/v1/trips",
        headers=user_headers(client),
        json=payload,
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "trip_activity_destination_mismatch"


def test_user_can_update_and_archive_trip(client) -> None:
    destination_a, _ = create_destinations(client)
    headers = user_headers(client)
    trip = create_trip(client, headers, [destination_a["destination_id"]])

    update_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}",
        headers=headers,
        json={
            "title": "Updated Trip",
            "notes": "Updated notes.",
            "status": "ongoing",
        },
    )

    assert update_response.status_code == 200
    assert update_response.json()["title"] == "Updated Trip"
    assert update_response.json()["status"] == "ongoing"

    archive_response = client.delete(f"/api/v1/trips/{trip['trip_id']}", headers=headers)

    assert archive_response.status_code == 200
    assert archive_response.json()["status"] == "archived"

    list_response = client.get("/api/v1/trips", headers=headers)

    assert list_response.status_code == 200
    assert list_response.json() == []

    archived_response = client.get(
        "/api/v1/trips",
        headers=headers,
        params={"include_archived": True},
    )

    assert archived_response.status_code == 200
    assert archived_response.json()[0]["status"] == "archived"


def test_user_can_save_and_get_trip_route(client) -> None:
    destination_a, _ = create_destinations(client)
    headers = user_headers(client)
    trip = create_trip(client, headers, [destination_a["destination_id"]])

    save_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=headers,
        json=route_payload(destination_a["destination_id"]),
    )

    assert save_response.status_code == 200
    assert save_response.json()["route_provider"] == "osrm"
    assert save_response.json()["total_distance_km"] == "12.50"

    get_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=headers,
    )

    assert get_response.status_code == 200
    assert get_response.json()["trip_id"] == trip["trip_id"]


def test_user_can_replace_saved_trip_route(client) -> None:
    destination_a, _ = create_destinations(client)
    headers = user_headers(client)
    trip = create_trip(client, headers, [destination_a["destination_id"]])

    first_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=headers,
        json=route_payload(destination_a["destination_id"]),
    )
    replacement_payload = route_payload(destination_a["destination_id"])
    replacement_payload.update(
        {
            "route_provider": "haversine",
            "is_estimated": True,
            "total_distance_km": "20.00",
            "total_duration_minutes": 50,
            "warnings": ["OSRM unavailable; estimated route used."],
        }
    )

    second_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=headers,
        json=replacement_payload,
    )

    assert first_response.status_code == 200
    assert second_response.status_code == 200
    assert second_response.json()["trip_route_id"] == first_response.json()["trip_route_id"]
    assert second_response.json()["route_provider"] == "haversine"
    assert second_response.json()["total_distance_km"] == "20.00"


def test_get_trip_route_returns_404_when_missing(client) -> None:
    destination_a, _ = create_destinations(client)
    headers = user_headers(client)
    trip = create_trip(client, headers, [destination_a["destination_id"]])

    response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=headers,
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "trip_route_not_found"


def test_trip_route_rejects_malformed_stop(client) -> None:
    destination_a, _ = create_destinations(client)
    headers = user_headers(client)
    trip = create_trip(client, headers, [destination_a["destination_id"]])
    payload = route_payload(destination_a["destination_id"])
    payload["stops"][0]["lat"] = 999

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=headers,
        json=payload,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_trip_route_rejects_destination_outside_trip(client) -> None:
    destination_a, destination_b = create_destinations(client)
    headers = user_headers(client)
    trip = create_trip(client, headers, [destination_a["destination_id"]])

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=headers,
        json=route_payload(destination_b["destination_id"]),
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "trip_route_destination_mismatch"


def test_trip_route_rejects_leg_destination_outside_trip(client) -> None:
    destination_a, destination_b, destination_c = create_three_destinations(client)
    headers = user_headers(client)
    trip = create_trip(
        client,
        headers,
        [destination_a["destination_id"], destination_b["destination_id"]],
    )
    payload = two_stop_route_payload(
        destination_a["destination_id"],
        destination_b["destination_id"],
    )
    payload["legs"][0]["to_destination_id"] = destination_c["destination_id"]
    payload["legs"][0]["to_name"] = "Trip Stop C"

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=headers,
        json=payload,
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "trip_route_destination_mismatch"


def test_post_archive_endpoint_archives_trip(client) -> None:
    destination_a, _ = create_destinations(client)
    headers = user_headers(client)
    trip = create_trip(client, headers, [destination_a["destination_id"]])

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/archive",
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["status"] == "archived"
