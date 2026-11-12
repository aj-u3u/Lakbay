DESTINATION_PAYLOAD = {
    "name": "Budget Beach",
    "description": "A calm beach for budget testing.",
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


def create_destination(
    client,
    *,
    headers: dict[str, str] | None = None,
    overrides: dict | None = None,
) -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=headers or admin_headers(client),
        json={**DESTINATION_PAYLOAD, **(overrides or {})},
    )

    assert response.status_code == 201

    return response.json()


def create_accommodation(
    client,
    *,
    destination_id: int,
    headers: dict[str, str],
    price: str = "1800.00",
) -> dict:
    response = client.post(
        f"/api/v1/destinations/{destination_id}/accommodations",
        headers=headers,
        json={
            "name": "Budget Stay",
            "room_type": "Standard Room",
            "price": price,
            "capacity": 2,
            "description": "Simple room near the destination.",
        },
    )

    assert response.status_code == 201

    return response.json()


def create_transportation(
    client,
    *,
    destination_id: int,
    headers: dict[str, str],
    price: str = "500.00",
) -> dict:
    response = client.post(
        f"/api/v1/destinations/{destination_id}/transportations",
        headers=headers,
        json={
            "vehicle_type": "Van",
            "transport_mode": "public_transport",
            "route_from": "Davao City",
            "route_to": "Budget Beach",
            "price": price,
            "duration_minutes": 180,
            "duration_text": "3 hours",
        },
    )

    assert response.status_code == 201

    return response.json()


def test_user_can_estimate_budget(client) -> None:
    admin = admin_headers(client)
    destination = create_destination(client, headers=admin)
    accommodation = create_accommodation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )
    transportation = create_transportation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.00",
            "traveler_count": 2,
            "day_count": 3,
            "destination_ids": [destination["destination_id"]],
            "accommodation_ids": [accommodation["accommodation_id"]],
            "transportation_ids": [transportation["transportation_id"]],
            "meal_cost_per_day": "500.00",
            "miscellaneous_cost": "300.00",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total_estimated_cost"] == "7100.00"
    assert body["remaining_budget"] == "2900.00"
    assert body["over_budget_amount"] == "0.00"
    assert body["is_over_budget"] is False
    assert body["percent_used"] == "71.00"
    assert body["breakdown"] == {
        "destinations": "1500.00",
        "accommodations": "1800.00",
        "transportation": "500.00",
        "meals": "3000.00",
        "miscellaneous": "300.00",
    }


def test_budget_estimate_sums_multiple_destinations_and_rates(client) -> None:
    admin = admin_headers(client)
    first_destination = create_destination(client, headers=admin)
    second_destination = create_destination(
        client,
        headers=admin,
        overrides={
            "name": "Budget Mountain",
            "category": "mountain",
            "lat": 7.01,
            "lng": 125.40,
            "estimated_cost": "2500.00",
        },
    )
    first_accommodation = create_accommodation(
        client,
        destination_id=first_destination["destination_id"],
        headers=admin,
        price="1200.00",
    )
    second_accommodation = create_accommodation(
        client,
        destination_id=second_destination["destination_id"],
        headers=admin,
        price="1800.00",
    )
    first_transportation = create_transportation(
        client,
        destination_id=first_destination["destination_id"],
        headers=admin,
        price="500.00",
    )
    second_transportation = create_transportation(
        client,
        destination_id=second_destination["destination_id"],
        headers=admin,
        price="700.00",
    )

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "15000.00",
            "traveler_count": 3,
            "day_count": 2,
            "destination_ids": [
                first_destination["destination_id"],
                second_destination["destination_id"],
            ],
            "accommodation_ids": [
                first_accommodation["accommodation_id"],
                second_accommodation["accommodation_id"],
            ],
            "transportation_ids": [
                first_transportation["transportation_id"],
                second_transportation["transportation_id"],
            ],
            "meal_cost_per_day": "300.00",
            "miscellaneous_cost": "400.00",
        },
    )

    assert response.status_code == 200
    body = response.json()
    assert body["total_estimated_cost"] == "10400.00"
    assert body["remaining_budget"] == "4600.00"
    assert body["percent_used"] == "69.33"
    assert body["breakdown"] == {
        "destinations": "4000.00",
        "accommodations": "3000.00",
        "transportation": "1200.00",
        "meals": "1800.00",
        "miscellaneous": "400.00",
    }


def test_budget_estimate_requires_authentication(client) -> None:
    destination = create_destination(client)

    response = client.post(
        "/api/v1/budgets/estimate",
        json={
            "total_budget": "10000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [destination["destination_id"]],
        },
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_over_budget_estimate_returns_over_budget_result(client) -> None:
    destination = create_destination(client)

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "1000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [destination["destination_id"]],
        },
    )

    assert response.status_code == 200
    assert response.json()["is_over_budget"] is True
    assert response.json()["over_budget_amount"] == "500.00"
    assert response.json()["percent_used"] == "150.00"


def test_exact_budget_has_zero_remaining_and_zero_overage(client) -> None:
    destination = create_destination(client)

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "1500.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [destination["destination_id"]],
        },
    )

    assert response.status_code == 200
    assert response.json()["remaining_budget"] == "0.00"
    assert response.json()["over_budget_amount"] == "0.00"
    assert response.json()["is_over_budget"] is False


def test_missing_destination_is_rejected(client) -> None:
    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [999],
        },
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "destination_not_found"


def test_inactive_destination_is_rejected(client) -> None:
    admin = admin_headers(client)
    destination = create_destination(client, headers=admin)
    client.delete(
        f"/api/v1/destinations/{destination['destination_id']}",
        headers=admin,
    )

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [destination["destination_id"]],
        },
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "destination_not_found"


def test_unavailable_accommodation_is_rejected(client) -> None:
    admin = admin_headers(client)
    destination = create_destination(client, headers=admin)
    accommodation = create_accommodation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )
    client.delete(
        f"/api/v1/accommodations/{accommodation['accommodation_id']}",
        headers=admin,
    )

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [destination["destination_id"]],
            "accommodation_ids": [accommodation["accommodation_id"]],
        },
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "accommodation_not_found"


def test_unavailable_transportation_is_rejected(client) -> None:
    admin = admin_headers(client)
    destination = create_destination(client, headers=admin)
    transportation = create_transportation(
        client,
        destination_id=destination["destination_id"],
        headers=admin,
    )
    client.delete(
        f"/api/v1/transportations/{transportation['transportation_id']}",
        headers=admin,
    )

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [destination["destination_id"]],
            "transportation_ids": [transportation["transportation_id"]],
        },
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "transportation_not_found"


def test_accommodation_must_belong_to_selected_destination(client) -> None:
    admin = admin_headers(client)
    selected = create_destination(client, headers=admin)
    other = create_destination(
        client,
        headers=admin,
        overrides={"name": "Other Destination", "lat": 7.01, "lng": 125.40},
    )
    accommodation = create_accommodation(
        client,
        destination_id=other["destination_id"],
        headers=admin,
    )

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [selected["destination_id"]],
            "accommodation_ids": [accommodation["accommodation_id"]],
        },
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "accommodation_destination_mismatch"


def test_transportation_must_belong_to_selected_destination(client) -> None:
    admin = admin_headers(client)
    selected = create_destination(client, headers=admin)
    other = create_destination(
        client,
        headers=admin,
        overrides={"name": "Other Destination", "lat": 7.01, "lng": 125.40},
    )
    transportation = create_transportation(
        client,
        destination_id=other["destination_id"],
        headers=admin,
    )

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [selected["destination_id"]],
            "transportation_ids": [transportation["transportation_id"]],
        },
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "transportation_destination_mismatch"


def test_budget_estimate_rejects_invalid_money_precision(client) -> None:
    destination = create_destination(client)

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.999",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [destination["destination_id"]],
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_budget_estimate_rejects_zero_total_budget(client) -> None:
    destination = create_destination(client)

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "0.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [destination["destination_id"]],
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_budget_estimate_rejects_excessive_traveler_and_day_counts(client) -> None:
    destination = create_destination(client)

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.00",
            "traveler_count": 101,
            "day_count": 366,
            "destination_ids": [destination["destination_id"]],
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_budget_estimate_rejects_duplicate_ids(client) -> None:
    destination = create_destination(client)

    response = client.post(
        "/api/v1/budgets/estimate",
        headers=user_headers(client),
        json={
            "total_budget": "10000.00",
            "traveler_count": 1,
            "day_count": 1,
            "destination_ids": [
                destination["destination_id"],
                destination["destination_id"],
            ],
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"
