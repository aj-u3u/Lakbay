DESTINATION_PAYLOAD = {
    "name": "Test Beach",
    "description": "A calm beach for testing.",
    "district": "Davao Oriental",
    "location": "Mati City",
    "category": "beach",
    "vibes": "relaxed, coastal",
    "activities": "swimming, photography",
    "lat": 6.9487,
    "lng": 126.2542,
    "estimated_cost": "1500.00",
    "entrance_fee": "100",
    "operating_hours": "Daytime",
    "best_time_to_visit": "Morning",
    "budget_class": "mid_range",
    "crowd_level": "moderate",
    "difficulty_level": "easy",
    "stay_duration_type": "full_day",
    "transport_accessibility": "moderate",
    "is_kid_friendly": True,
    "family_friendly": True,
    "group_friendly": True,
}


def admin_headers(client) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Admin User",
            "email": "admin@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def user_headers(client) -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Normal User",
            "email": "user@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def create_destination(client, headers: dict[str, str] | None = None) -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=headers or admin_headers(client),
        json=DESTINATION_PAYLOAD,
    )

    assert response.status_code == 201

    return response.json()


def test_admin_can_create_destination(client) -> None:
    destination = create_destination(client)

    assert destination["name"] == "Test Beach"
    assert destination["district"] == "Davao Oriental"
    assert destination["is_active"] is True


def test_normal_user_cannot_create_destination(client) -> None:
    response = client.post(
        "/api/v1/destinations",
        headers=user_headers(client),
        json=DESTINATION_PAYLOAD,
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "admin_required"


def test_user_can_browse_and_filter_destinations(client) -> None:
    headers = admin_headers(client)
    create_destination(client, headers=headers)
    client.post(
        "/api/v1/destinations",
        headers=headers,
        json={
            **DESTINATION_PAYLOAD,
            "name": "Mountain Test",
            "district": "Davao City",
            "category": "mountain",
            "lat": 7.0088,
            "lng": 125.3992,
        },
    )

    response = client.get("/api/v1/destinations?category=beach")

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["name"] == "Test Beach"


def test_destination_list_supports_pagination(client) -> None:
    headers = admin_headers(client)
    create_destination(client, headers=headers)
    client.post(
        "/api/v1/destinations",
        headers=headers,
        json={
            **DESTINATION_PAYLOAD,
            "name": "Mountain Test",
            "district": "Davao City",
            "category": "mountain",
            "lat": 7.0088,
            "lng": 125.3992,
        },
    )

    response = client.get("/api/v1/destinations?limit=1&offset=1")

    assert response.status_code == 200
    body = response.json()
    assert len(body) == 1
    assert body[0]["name"] == "Test Beach"


def test_destination_list_rejects_excessive_limit(client) -> None:
    response = client.get("/api/v1/destinations?limit=101")

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_get_destination_by_id(client) -> None:
    destination = create_destination(client)

    response = client.get(f"/api/v1/destinations/{destination['destination_id']}")

    assert response.status_code == 200
    assert response.json()["name"] == "Test Beach"


def test_admin_can_update_destination(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)

    response = client.patch(
        f"/api/v1/destinations/{destination['destination_id']}",
        headers=headers,
        json={
            "category": "coastal",
            "estimated_cost": "1800.50",
        },
    )

    assert response.status_code == 200
    assert response.json()["category"] == "coastal"
    assert response.json()["estimated_cost"] == "1800.50"


def test_destination_rejects_invalid_money_precision(client) -> None:
    response = client.post(
        "/api/v1/destinations",
        headers=admin_headers(client),
        json={
            **DESTINATION_PAYLOAD,
            "estimated_cost": "1500.999",
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_deactivated_destination_is_hidden_from_public_browse(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)

    delete_response = client.delete(
        f"/api/v1/destinations/{destination['destination_id']}",
        headers=headers,
    )
    list_response = client.get("/api/v1/destinations")
    get_response = client.get(f"/api/v1/destinations/{destination['destination_id']}")

    assert delete_response.status_code == 200
    assert delete_response.json()["is_active"] is False
    assert list_response.status_code == 200
    assert list_response.json() == []
    assert get_response.status_code == 404


def test_admin_can_create_and_user_can_list_accommodations(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)

    create_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/accommodations",
        headers=headers,
        json={
            "name": "Beach Stay",
            "room_type": "Standard Room",
            "price": "1800.00",
            "capacity": 2,
            "description": "Simple room near the beach.",
        },
    )
    list_response = client.get(
        f"/api/v1/destinations/{destination['destination_id']}/accommodations"
    )

    assert create_response.status_code == 201
    assert list_response.status_code == 200
    assert list_response.json()[0]["name"] == "Beach Stay"


def test_admin_can_update_accommodation(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)
    accommodation = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/accommodations",
        headers=headers,
        json={
            "name": "Beach Stay",
            "room_type": "Standard Room",
            "price": "1800.00",
        },
    ).json()

    response = client.patch(
        f"/api/v1/accommodations/{accommodation['accommodation_id']}",
        headers=headers,
        json={
            "price": "2200.50",
            "capacity": 3,
        },
    )

    assert response.status_code == 200
    assert response.json()["price"] == "2200.50"
    assert response.json()["capacity"] == 3


def test_accommodation_rejects_invalid_money_precision(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)

    response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/accommodations",
        headers=headers,
        json={
            "name": "Beach Stay",
            "room_type": "Standard Room",
            "price": "1800.999",
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_accommodation_for_missing_destination_is_rejected(client) -> None:
    response = client.post(
        "/api/v1/destinations/999/accommodations",
        headers=admin_headers(client),
        json={
            "name": "Missing Stay",
            "room_type": "Standard Room",
            "price": "1800.00",
        },
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "destination_not_found"


def test_deleted_accommodation_is_hidden_from_public_list(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)
    accommodation = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/accommodations",
        headers=headers,
        json={
            "name": "Beach Stay",
            "room_type": "Standard Room",
            "price": "1800.00",
        },
    ).json()

    delete_response = client.delete(
        f"/api/v1/accommodations/{accommodation['accommodation_id']}",
        headers=headers,
    )
    list_response = client.get(
        f"/api/v1/destinations/{destination['destination_id']}/accommodations"
    )

    assert delete_response.status_code == 200
    assert delete_response.json()["is_available"] is False
    assert list_response.json() == []


def test_admin_can_create_and_user_can_list_transportation(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)

    create_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/transportations",
        headers=headers,
        json={
            "vehicle_type": "Van",
            "transport_mode": "public_transport",
            "route_from": "Davao City",
            "route_to": "Test Beach",
            "price": "500.00",
            "duration_minutes": 180,
            "duration_text": "3 hours",
        },
    )
    list_response = client.get(
        f"/api/v1/destinations/{destination['destination_id']}/transportations"
    )

    assert create_response.status_code == 201
    assert list_response.status_code == 200
    assert list_response.json()[0]["vehicle_type"] == "Van"


def test_admin_can_update_transportation(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)
    transportation = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/transportations",
        headers=headers,
        json={
            "vehicle_type": "Van",
            "transport_mode": "public_transport",
            "route_from": "Davao City",
            "route_to": "Test Beach",
            "price": "500.00",
        },
    ).json()

    response = client.patch(
        f"/api/v1/transportations/{transportation['transportation_id']}",
        headers=headers,
        json={
            "price": "550.75",
            "duration_minutes": 190,
        },
    )

    assert response.status_code == 200
    assert response.json()["price"] == "550.75"
    assert response.json()["duration_minutes"] == 190


def test_transportation_rejects_invalid_money_precision(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)

    response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/transportations",
        headers=headers,
        json={
            "vehicle_type": "Van",
            "transport_mode": "public_transport",
            "route_from": "Davao City",
            "route_to": "Test Beach",
            "price": "500.999",
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_transportation_for_missing_destination_is_rejected(client) -> None:
    response = client.post(
        "/api/v1/destinations/999/transportations",
        headers=admin_headers(client),
        json={
            "vehicle_type": "Van",
            "transport_mode": "public_transport",
            "route_from": "Davao City",
            "route_to": "Missing Destination",
            "price": "500.00",
        },
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "destination_not_found"


def test_deleted_transportation_is_hidden_from_public_list(client) -> None:
    headers = admin_headers(client)
    destination = create_destination(client, headers=headers)
    transportation = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/transportations",
        headers=headers,
        json={
            "vehicle_type": "Van",
            "transport_mode": "public_transport",
            "route_from": "Davao City",
            "route_to": "Test Beach",
            "price": "500.00",
        },
    ).json()

    delete_response = client.delete(
        f"/api/v1/transportations/{transportation['transportation_id']}",
        headers=headers,
    )
    list_response = client.get(
        f"/api/v1/destinations/{destination['destination_id']}/transportations"
    )

    assert delete_response.status_code == 200
    assert delete_response.json()["is_available"] is False
    assert list_response.json() == []
