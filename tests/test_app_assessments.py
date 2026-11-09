def _register(client, email: str, *, admin: bool = False) -> dict[str, str]:
    payload = {
        "full_name": "Assessment Tester",
        "email": email,
        "password": "password123",
        "confirm_password": "password123",
    }
    path = "/api/v1/auth/register/admin" if admin else "/api/v1/auth/register"
    if admin:
        payload["admin_registration_code"] = "admin-test-code"
    response = client.post(path, json=payload)
    assert response.status_code == 201
    return {"Authorization": f"Bearer {response.json()['tokens']['access_token']}"}


def _trip(client, owner: dict[str, str], admin: dict[str, str], *, completed: bool) -> int:
    destination = client.post(
        "/api/v1/destinations",
        headers=admin,
        json={
            "name": "Assessment Stop",
            "district": "Davao City",
            "category": "park",
            "lat": 7.0644,
            "lng": 125.6078,
            "estimated_cost": "100.00",
        },
    )
    assert destination.status_code == 201
    created = client.post(
        "/api/v1/trips",
        headers=owner,
        json={
            "title": "Assessment Trip",
            "traveler_count": 2,
            "total_budget": "1000.00",
            "destination_ids": [destination.json()["destination_id"]],
            "itinerary_days": [],
        },
    )
    assert created.status_code == 201
    trip_id = created.json()["trip_id"]
    if completed:
        updated = client.patch(
            f"/api/v1/trips/{trip_id}", headers=owner, json={"status": "completed"}
        )
        assert updated.status_code == 200
    return trip_id


def _payload(**overrides) -> dict:
    payload = {
        "functional_suitability_rating": 5,
        "information_accuracy_rating": 4,
        "performance_rating": 3,
        "interaction_rating": 4,
        "reliability_rating": 5,
        "sharing_clarity_rating": None,
        "comment": "  Easy to follow.  ",
        "app_version": "1.2.3",
    }
    payload.update(overrides)
    return payload


def test_assessment_requires_completed_trip_and_active_member(client) -> None:
    owner = _register(client, "assessment-owner@example.com")
    outsider = _register(client, "assessment-outsider@example.com")
    admin = _register(client, "assessment-admin@example.com", admin=True)
    trip_id = _trip(client, owner, admin, completed=False)
    path = f"/api/v1/trips/{trip_id}/app-assessment"

    assert client.get(f"{path}/me").status_code == 401
    assert client.get(f"{path}/me", headers=outsider).status_code == 404
    assert client.post(path, headers=outsider, json=_payload()).status_code == 404
    assert client.get(f"{path}/me", headers=owner).json() == {"assessment": None}
    planned = client.post(path, headers=owner, json=_payload())
    assert planned.status_code == 400
    assert planned.json()["error"]["code"] == "trip_not_completed"


def test_member_submission_is_private_and_unique(client) -> None:
    owner = _register(client, "assessment-owner2@example.com")
    member = _register(client, "assessment-member2@example.com")
    admin = _register(client, "assessment-admin2@example.com", admin=True)
    trip_id = _trip(client, owner, admin, completed=True)
    added = client.post(
        f"/api/v1/trips/{trip_id}/members",
        headers=owner,
        json={"email": "assessment-member2@example.com", "role": "member"},
    )
    assert added.status_code == 201
    path = f"/api/v1/trips/{trip_id}/app-assessment"

    submitted = client.post(path, headers=member, json=_payload())
    assert submitted.status_code == 201
    body = submitted.json()
    assert body["comment"] == "Easy to follow."
    assert body["sharing_clarity_rating"] is None
    assert body["question_version"] == 1
    assert client.get(f"{path}/me", headers=member).json()["assessment"] == body
    assert client.get(f"{path}/me", headers=owner).json() == {"assessment": None}
    duplicate = client.post(path, headers=member, json=_payload())
    assert duplicate.status_code == 409
    assert duplicate.json()["error"]["code"] == "app_assessment_already_exists"

    removed = client.delete(
        f"/api/v1/trips/{trip_id}/members/{added.json()['trip_member_id']}",
        headers=owner,
    )
    assert removed.status_code in (200, 204)
    assert client.get(f"{path}/me", headers=member).status_code == 404


def test_assessment_validation_and_admin_results(client) -> None:
    owner = _register(client, "assessment-owner3@example.com")
    admin = _register(client, "assessment-admin3@example.com", admin=True)
    trip_id = _trip(client, owner, admin, completed=True)
    path = f"/api/v1/trips/{trip_id}/app-assessment"
    for bad in (
        _payload(performance_rating=6),
        _payload(performance_rating=0),
        _payload(sharing_clarity_rating=None, functional_suitability_rating=None,
                 information_accuracy_rating=None, performance_rating=None,
                 interaction_rating=None, reliability_rating=None),
        {key: value for key, value in _payload().items() if key != "performance_rating"},
    ):
        assert client.post(path, headers=owner, json=bad).status_code == 422

    submitted = client.post(path, headers=owner, json=_payload())
    assert submitted.status_code == 201
    summary_path = "/api/v1/evaluation/app-assessments/summary"
    list_path = "/api/v1/evaluation/app-assessments"
    for endpoint in (summary_path, list_path):
        assert client.get(endpoint).status_code == 401
        assert client.get(endpoint, headers=owner).status_code == 403
        assert client.get(f"{endpoint}?window_days=0", headers=admin).status_code == 422

    summary = client.get(summary_path, headers=admin)
    assert summary.status_code == 200
    result = summary.json()
    assert result["response_count"] == 1
    assert result["participant_count"] == 1
    assert result["questions"]["performance_rating"] == {
        "answered": 1,
        "not_applicable": 0,
        "average": 3.0,
        "ratings": {"1": 0, "2": 0, "3": 1, "4": 0, "5": 0},
    }
    assert result["questions"]["sharing_clarity_rating"]["answered"] == 0
    assert result["questions"]["sharing_clarity_rating"]["not_applicable"] == 1
    assert result["questions"]["sharing_clarity_rating"]["average"] is None
    listed = client.get(list_path, headers=admin)
    assert listed.status_code == 200
    assert listed.json()["total"] == 1
    item = listed.json()["items"][0]
    assert item["comment"] == "Easy to follow."
    assert "user_id" not in item and "trip_id" not in item and "email" not in item
