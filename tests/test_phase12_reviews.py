from itertools import count


ADMIN_COUNTER = count(1)


DESTINATION = {
    "name": "Review Test Stop",
    "description": "A destination for review tests.",
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
            "full_name": "Review Admin",
            "email": f"review-admin-{admin_index}@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "admin-test-code",
        },
    )

    assert response.status_code == 201

    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def create_destination(client, *, name: str = "Review Test Stop") -> dict:
    response = client.post(
        "/api/v1/destinations",
        headers=admin_headers(client),
        json={**DESTINATION, "name": name},
    )

    assert response.status_code == 201

    return response.json()


def create_trip(client, headers: dict[str, str], *, completed: bool = True) -> dict:
    destination = create_destination(client)
    response = client.post(
        "/api/v1/trips",
        headers=headers,
        json={
            "title": "Review Trip",
            "description": "A trip for review tests.",
            "traveler_count": 2,
            "total_budget": "10000.00",
            "estimated_total_cost": "2500.00",
            "destination_ids": [destination["destination_id"]],
            "itinerary_days": [],
        },
    )

    assert response.status_code == 201
    trip = response.json()

    if completed:
        update_response = client.patch(
            f"/api/v1/trips/{trip['trip_id']}",
            headers=headers,
            json={"status": "completed"},
        )

        assert update_response.status_code == 200
        trip = update_response.json()

    return trip


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


def review_payload(**overrides) -> dict:
    payload = {
        "post_trip_rating": 5,
        "accuracy_rating": 4,
        "route_efficiency_rating": 5,
        "budget_adherence_rating": 4,
        "overall_experience_rating": 5,
        "comments": "The itinerary was useful.",
    }
    payload.update(overrides)

    return payload


def create_review(
    client,
    *,
    headers: dict[str, str],
    trip_id: int,
    **overrides,
) -> dict:
    response = client.post(
        f"/api/v1/trips/{trip_id}/reviews",
        headers=headers,
        json=review_payload(**overrides),
    )

    assert response.status_code == 201

    return response.json()


def test_reviews_require_authentication(client) -> None:
    response = client.get("/api/v1/trips/1/reviews")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_review_requires_completed_trip(client) -> None:
    owner_headers = register_user(client, email="review-owner-planned@example.com")
    trip = create_trip(client, owner_headers, completed=False)

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/reviews",
        headers=owner_headers,
        json=review_payload(),
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "trip_not_completed"


def test_active_member_can_create_and_list_review(client) -> None:
    owner_headers = register_user(client, email="review-owner-create@example.com")
    member_headers = register_user(client, email="review-member-create@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="review-member-create@example.com",
    )
    destination_id = trip["destinations"][0]["destination_id"]

    review = create_review(
        client,
        headers=member_headers,
        trip_id=trip["trip_id"],
        destination_id=destination_id,
        comments="  Great match for our group.  ",
    )
    list_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reviews",
        headers=owner_headers,
    )

    assert review["email"] == "review-member-create@example.com"
    assert review["destination_id"] == destination_id
    assert review["destination_name"] == "Review Test Stop"
    assert review["comments"] == "Great match for our group."
    assert list_response.status_code == 200
    assert list_response.json()[0]["trip_review_id"] == review["trip_review_id"]


def test_duplicate_trip_level_review_is_rejected(client) -> None:
    owner_headers = register_user(client, email="review-owner-duplicate@example.com")
    trip = create_trip(client, owner_headers)
    create_review(client, headers=owner_headers, trip_id=trip["trip_id"])

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/reviews",
        headers=owner_headers,
        json=review_payload(overall_experience_rating=4),
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "trip_review_already_exists"


def test_trip_level_and_destination_level_reviews_are_distinct(client) -> None:
    owner_headers = register_user(client, email="review-owner-destination-duplicate@example.com")
    trip = create_trip(client, owner_headers)
    destination_id = trip["destinations"][0]["destination_id"]
    trip_review = create_review(client, headers=owner_headers, trip_id=trip["trip_id"])
    destination_review = create_review(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        destination_id=destination_id,
    )

    duplicate_destination_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/reviews",
        headers=owner_headers,
        json=review_payload(destination_id=destination_id),
    )

    assert trip_review["destination_id"] is None
    assert destination_review["destination_id"] == destination_id
    assert duplicate_destination_response.status_code == 400
    assert duplicate_destination_response.json()["error"]["code"] == "trip_review_already_exists"


def test_review_destination_must_belong_to_trip(client) -> None:
    owner_headers = register_user(client, email="review-owner-destination@example.com")
    trip = create_trip(client, owner_headers)
    other_destination = create_destination(client, name="Other Review Stop")

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/reviews",
        headers=owner_headers,
        json=review_payload(destination_id=other_destination["destination_id"]),
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "trip_review_destination_mismatch"


def test_only_review_author_can_update_and_delete(client) -> None:
    owner_headers = register_user(client, email="review-owner-permission@example.com")
    author_headers = register_user(client, email="review-author-permission@example.com")
    other_headers = register_user(client, email="review-other-permission@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="review-author-permission@example.com",
    )
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="review-other-permission@example.com",
    )
    review = create_review(client, headers=author_headers, trip_id=trip["trip_id"])

    denied_update = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/reviews/{review['trip_review_id']}",
        headers=other_headers,
        json={"comments": "Not mine."},
    )
    author_update = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/reviews/{review['trip_review_id']}",
        headers=author_headers,
        json={"comments": "Updated feedback.", "overall_experience_rating": 4},
    )
    denied_delete = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/reviews/{review['trip_review_id']}",
        headers=other_headers,
    )
    author_delete = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/reviews/{review['trip_review_id']}",
        headers=author_headers,
    )

    assert denied_update.status_code == 403
    assert denied_update.json()["error"]["code"] == "trip_review_permission_denied"
    assert author_update.status_code == 200
    assert author_update.json()["comments"] == "Updated feedback."
    assert author_update.json()["overall_experience_rating"] == 4
    assert denied_delete.status_code == 403
    assert denied_delete.json()["error"]["code"] == "trip_review_permission_denied"
    assert author_delete.status_code == 200
    assert author_delete.json()["status"] == "deleted"


def test_outsider_and_removed_member_cannot_access_reviews(client) -> None:
    owner_headers = register_user(client, email="review-owner-access@example.com")
    member_headers = register_user(client, email="review-member-access@example.com")
    outsider_headers = register_user(client, email="review-outsider-access@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="review-member-access@example.com",
    )

    outsider_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reviews",
        headers=outsider_headers,
    )
    remove_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/members/{member['trip_member_id']}",
        headers=owner_headers,
    )
    removed_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reviews/summary",
        headers=member_headers,
    )

    assert outsider_response.status_code == 404
    assert outsider_response.json()["error"]["code"] == "trip_not_found"
    assert remove_response.status_code == 200
    assert removed_response.status_code == 404
    assert removed_response.json()["error"]["code"] == "trip_not_found"


def test_review_summary_calculates_averages_and_excludes_deleted(client) -> None:
    owner_headers = register_user(client, email="review-owner-summary@example.com")
    member_headers = register_user(client, email="review-member-summary@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="review-member-summary@example.com",
    )
    deleted_review = create_review(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        overall_experience_rating=1,
    )
    delete_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/reviews/{deleted_review['trip_review_id']}",
        headers=owner_headers,
    )
    create_review(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        post_trip_rating=5,
        accuracy_rating=4,
        route_efficiency_rating=5,
        budget_adherence_rating=4,
        overall_experience_rating=5,
    )
    create_review(
        client,
        headers=member_headers,
        trip_id=trip["trip_id"],
        post_trip_rating=4,
        accuracy_rating=2,
        route_efficiency_rating=3,
        budget_adherence_rating=2,
        overall_experience_rating=3,
    )
    create_review(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        destination_id=trip["destinations"][0]["destination_id"],
        post_trip_rating=1,
        accuracy_rating=1,
        route_efficiency_rating=1,
        budget_adherence_rating=1,
        overall_experience_rating=1,
    )

    summary_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reviews/summary",
        headers=owner_headers,
    )
    body = summary_response.json()

    assert delete_response.status_code == 200
    assert summary_response.status_code == 200
    assert body["review_count"] == 2
    assert body["average_post_trip_rating"] == "4.50"
    assert body["average_accuracy_rating"] == "3.00"
    assert body["average_route_efficiency_rating"] == "4.00"
    assert body["average_budget_adherence_rating"] == "3.00"
    assert body["average_overall_experience_rating"] == "4.00"
