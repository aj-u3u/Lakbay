DESTINATION_PAYLOAD = {
    "name": "Beach Match",
    "description": "A calm beach for testing recommendations.",
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


def user_headers(client, *, email: str = "user@example.com") -> dict[str, str]:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Normal User",
            "email": email,
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
        json={
            **DESTINATION_PAYLOAD,
            **(overrides or {}),
        },
    )

    assert response.status_code == 201

    return response.json()


def test_user_can_request_ranked_recommendations(client) -> None:
    headers = admin_headers(client)
    create_destination(client, headers=headers)
    create_destination(
        client,
        headers=headers,
        overrides={
            "name": "Mountain Test",
            "district": "Davao City",
            "category": "mountain",
            "vibes": "adventure, cool weather",
            "activities": "hiking",
            "budget_class": "premium",
            "difficulty_level": "hard",
            "stay_duration_type": "multi_day",
            "family_friendly": False,
            "lat": 7.0088,
            "lng": 125.3992,
        },
    )

    response = client.post(
        "/api/v1/recommendations",
        headers=user_headers(client),
        json={
            "preferred_categories": ["beach"],
            "preferred_vibes": ["relaxed"],
            "preferred_activities": ["swimming"],
            "preferred_districts": ["Davao Oriental"],
            "budget_class": "mid_range",
            "difficulty_level": "easy",
            "stay_duration_type": "full_day",
            "family_friendly": True,
            "limit": 5,
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["preference_signal_id"] > 0
    assert len(body["recommendations"]) == 1
    assert body["recommendations"][0]["name"] == "Beach Match"
    assert "category" in body["recommendations"][0]["matched_fields"]


def test_recommendations_require_authentication(client) -> None:
    response = client.post(
        "/api/v1/recommendations",
        json={"preferred_categories": ["beach"]},
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_inactive_destinations_are_excluded_from_recommendations(client) -> None:
    headers = admin_headers(client)
    active_destination = create_destination(client, headers=headers)
    inactive_destination = create_destination(
        client,
        headers=headers,
        overrides={
            "name": "Inactive Beach",
            "lat": 7.01,
            "lng": 125.40,
        },
    )
    client.delete(
        f"/api/v1/destinations/{inactive_destination['destination_id']}",
        headers=headers,
    )

    response = client.post(
        "/api/v1/recommendations",
        headers=user_headers(client),
        json={"preferred_categories": ["beach"]},
    )

    names = [item["name"] for item in response.json()["recommendations"]]
    assert response.status_code == 201
    assert active_destination["name"] in names
    assert inactive_destination["name"] not in names


def test_latest_preference_is_saved_for_user(client) -> None:
    create_destination(client)
    headers = user_headers(client)
    client.post(
        "/api/v1/recommendations",
        headers=headers,
        json={
            "preferred_categories": ["Beach"],
            "preferred_vibes": ["Relaxed"],
            "budget_class": "Mid_Range",
        },
    )

    response = client.get(
        "/api/v1/recommendations/preferences/latest",
        headers=headers,
    )

    assert response.status_code == 200
    assert response.json()["preferred_categories"] == ["beach"]
    assert response.json()["preferred_vibes"] == ["relaxed"]
    assert response.json()["budget_class"] == "mid_range"


def test_interaction_updates_destination_popularity(client) -> None:
    destination = create_destination(client)
    headers = user_headers(client)

    view_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=headers,
        json={"interaction_type": "view"},
    )
    save_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=headers,
        json={"interaction_type": "save"},
    )
    rate_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=headers,
        json={"interaction_type": "rate", "rating": 4},
    )
    popularity_response = client.get(
        f"/api/v1/destinations/{destination['destination_id']}/popularity",
    )

    assert view_response.status_code == 201
    assert save_response.status_code == 201
    assert rate_response.status_code == 201
    assert popularity_response.status_code == 200
    assert popularity_response.json()["view_count"] == 1
    assert popularity_response.json()["save_count"] == 1
    assert popularity_response.json()["rating_count"] == 1
    assert popularity_response.json()["average_rating"] == "4.00"


def test_repeated_views_are_counted(client) -> None:
    destination = create_destination(client)
    headers = user_headers(client)

    first_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=headers,
        json={"interaction_type": "view"},
    )
    second_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=headers,
        json={"interaction_type": "view"},
    )
    popularity_response = client.get(
        f"/api/v1/destinations/{destination['destination_id']}/popularity",
    )

    assert first_response.status_code == 201
    assert second_response.status_code == 201
    assert popularity_response.json()["view_count"] == 2


def test_duplicate_save_does_not_inflate_popularity(client) -> None:
    destination = create_destination(client)
    headers = user_headers(client)

    first_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=headers,
        json={"interaction_type": "save"},
    )
    second_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=headers,
        json={"interaction_type": "save"},
    )
    popularity_response = client.get(
        f"/api/v1/destinations/{destination['destination_id']}/popularity",
    )

    assert first_response.status_code == 201
    assert second_response.status_code == 201
    assert (
        second_response.json()["interaction_id"]
        == first_response.json()["interaction_id"]
    )
    assert popularity_response.json()["save_count"] == 1
    assert popularity_response.json()["popularity_score"] == "3.00"


def test_repeated_rating_updates_existing_rating(client) -> None:
    destination = create_destination(client)
    first_user = user_headers(client)
    second_user = user_headers(client, email="second-user@example.com")

    client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=first_user,
        json={"interaction_type": "rate", "rating": 2},
    )
    update_response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=first_user,
        json={"interaction_type": "rate", "rating": 5},
    )
    client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=second_user,
        json={"interaction_type": "rate", "rating": 3},
    )
    popularity_response = client.get(
        f"/api/v1/destinations/{destination['destination_id']}/popularity",
    )

    assert update_response.status_code == 201
    assert update_response.json()["rating"] == 5
    assert popularity_response.json()["rating_count"] == 2
    assert popularity_response.json()["rating_sum"] == 8
    assert popularity_response.json()["average_rating"] == "4.00"


def test_blank_preference_item_is_rejected(client) -> None:
    response = client.post(
        "/api/v1/recommendations",
        headers=user_headers(client),
        json={"preferred_categories": ["   "]},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_invalid_rating_interaction_is_rejected(client) -> None:
    destination = create_destination(client)

    response = client.post(
        f"/api/v1/destinations/{destination['destination_id']}/interactions",
        headers=user_headers(client),
        json={"interaction_type": "rate"},
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_missing_destination_interaction_returns_404(client) -> None:
    response = client.post(
        "/api/v1/destinations/999/interactions",
        headers=user_headers(client),
        json={"interaction_type": "view"},
    )

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "destination_not_found"


def test_popularity_can_influence_future_recommendations(client) -> None:
    headers = admin_headers(client)
    create_destination(client, headers=headers, overrides={"name": "A Beach"})
    popular = create_destination(
        client,
        headers=headers,
        overrides={
            "name": "Z Beach",
            "lat": 7.01,
            "lng": 125.40,
        },
    )
    user = user_headers(client)
    client.post(
        f"/api/v1/destinations/{popular['destination_id']}/interactions",
        headers=user,
        json={"interaction_type": "save"},
    )

    response = client.post(
        "/api/v1/recommendations",
        headers=user,
        json={"preferred_categories": ["beach"], "limit": 2},
    )

    assert response.status_code == 201
    assert response.json()["recommendations"][0]["name"] == "Z Beach"
    assert "popularity" in response.json()["recommendations"][0]["matched_fields"]
