from itertools import count


ADMIN_COUNTER = count(1)


DESTINATION = {
    "name": "Report Test Stop",
    "description": "A destination for report tests.",
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
            "full_name": "Report Admin",
            "email": f"report-admin-{admin_index}@example.com",
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


def create_trip(
    client,
    headers: dict[str, str],
    *,
    title: str = "Report Trip",
    description: str = "A trip for report tests.",
    notes: str = "Bring printed reservations.",
    itinerary_days=None,
) -> dict:
    destination = create_destination(client)
    response = client.post(
        "/api/v1/trips",
        headers=headers,
        json={
            "title": title,
            "description": description,
            "start_date": "2026-10-10",
            "end_date": "2026-10-12",
            "traveler_count": 2,
            "total_budget": "10000.00",
            "estimated_total_cost": "2500.00",
            "destination_ids": [destination["destination_id"]],
            "notes": notes,
            "itinerary_days": itinerary_days or [],
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


def save_route(client, *, headers: dict[str, str], trip: dict) -> dict:
    destination_id = trip["destinations"][0]["destination_id"]
    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/route",
        headers=headers,
        json={
            "travel_mode": "driving",
            "route_provider": "osrm",
            "is_estimated": False,
            "total_distance_km": "12.50",
            "total_duration_minutes": 30,
            "stops": [
                {
                    "order": 1,
                    "destination_id": destination_id,
                    "name": "Report Test Stop",
                    "lat": 7.0644,
                    "lng": 125.6078,
                    "is_origin": False,
                }
            ],
            "legs": [],
            "warnings": [],
        },
    )

    assert response.status_code == 200

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
            "title": "Group meal",
            "description": "Shared lunch.",
            "category": "meals",
            "amount": "300.00",
            "paid_by_trip_member_id": paid_by_trip_member_id,
            "expense_date": "2026-10-10",
            "notes": "Paid in cash.",
        },
    )

    assert response.status_code == 201

    return response.json()


def test_reports_require_authentication(client) -> None:
    response = client.get("/api/v1/trips/1/reports/summary")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_member_can_get_report_summary_with_route_and_expenses(client) -> None:
    owner_headers = register_user(client, email="report-owner-summary@example.com")
    register_user(client, email="report-member-summary@example.com")
    trip = create_trip(
        client,
        owner_headers,
        itinerary_days=[
            {
                "day_number": 1,
                "title": "Arrival Day",
                "summary": "Start with the first stop.",
                "activities": [
                    {
                        "activity_order": 1,
                        "time": "09:00",
                        "title": "Visit the park",
                        "estimated_cost": "100.00",
                    }
                ],
            }
        ],
    )
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="report-member-summary@example.com",
    )
    save_route(client, headers=owner_headers, trip=trip)
    create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=member["trip_member_id"],
    )

    response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reports/summary",
        headers=owner_headers,
    )
    body = response.json()

    assert response.status_code == 200
    assert body["trip"]["title"] == "Report Trip"
    assert body["destinations"][0]["name"] == "Report Test Stop"
    assert body["itinerary_days"][0]["activities"][0]["title"] == "Visit the park"
    assert body["route"]["route_provider"] == "osrm"
    assert body["expenses"]["total_spent"] == "300.00"
    assert len(body["members"]) == 2


def test_member_can_download_pdf_report(client) -> None:
    owner_headers = register_user(client, email="report-owner-pdf@example.com")
    trip = create_trip(client, owner_headers)

    response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reports/pdf",
        headers=owner_headers,
    )

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert "lakbay-trip" in response.headers["content-disposition"]
    assert response.content.startswith(b"%PDF")


def test_report_includes_saved_group_tasks(client) -> None:
    owner_headers = register_user(client, email="report-owner-tasks@example.com")
    trip = create_trip(client, owner_headers)
    task_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/tasks",
        headers=owner_headers,
        json={"title": "Book group hotel", "due_date": "2026-10-09"},
    )

    response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reports/summary",
        headers=owner_headers,
    )
    pdf_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reports/pdf",
        headers=owner_headers,
    )

    assert task_response.status_code == 201
    assert response.status_code == 200
    assert response.json()["tasks"] == [
        {"title": "Book group hotel", "status": "pending", "due_date": "2026-10-09"}
    ]
    assert pdf_response.status_code == 200
    assert pdf_response.content.startswith(b"%PDF")


def test_pdf_report_handles_full_data_and_markup_like_text(client) -> None:
    owner_headers = register_user(client, email="report-owner-rich-pdf@example.com")
    register_user(client, email="report-member-rich-pdf@example.com")
    trip = create_trip(
        client,
        owner_headers,
        title="Report <b>Trip",
        description="A report with markup-like text.",
        notes="Bring <b>cash",
        itinerary_days=[
            {
                "day_number": 1,
                "title": "Arrival <b>Day",
                "summary": "Start with <b>broken markup.",
                "activities": [
                    {
                        "activity_order": 1,
                        "time": "09:00",
                        "title": "Visit the park",
                        "estimated_cost": "100.00",
                    }
                ],
            }
        ],
    )
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="report-member-rich-pdf@example.com",
    )
    save_route(client, headers=owner_headers, trip=trip)
    create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=member["trip_member_id"],
    )

    response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reports/pdf",
        headers=owner_headers,
    )

    assert response.status_code == 200
    assert response.headers["content-type"] == "application/pdf"
    assert response.content.startswith(b"%PDF")


def test_report_summary_allows_missing_route(client) -> None:
    owner_headers = register_user(client, email="report-owner-no-route@example.com")
    trip = create_trip(client, owner_headers)

    response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reports/summary",
        headers=owner_headers,
    )

    assert response.status_code == 200
    assert response.json()["route"] is None


def test_report_summary_hides_removed_members(client) -> None:
    owner_headers = register_user(client, email="report-owner-removed-list@example.com")
    register_user(client, email="report-member-removed-list@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="report-member-removed-list@example.com",
    )
    remove_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/members/{member['trip_member_id']}",
        headers=owner_headers,
    )

    response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reports/summary",
        headers=owner_headers,
    )
    member_emails = {member["email"] for member in response.json()["members"]}

    assert remove_response.status_code == 200
    assert response.status_code == 200
    assert "report-owner-removed-list@example.com" in member_emails
    assert "report-member-removed-list@example.com" not in member_emails


def test_outsider_and_removed_member_cannot_access_reports(client) -> None:
    owner_headers = register_user(client, email="report-owner-access@example.com")
    member_headers = register_user(client, email="report-member-access@example.com")
    outsider_headers = register_user(client, email="report-outsider-access@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="report-member-access@example.com",
    )

    outsider_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reports/summary",
        headers=outsider_headers,
    )
    remove_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/members/{member['trip_member_id']}",
        headers=owner_headers,
    )
    removed_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/reports/pdf",
        headers=member_headers,
    )

    assert outsider_response.status_code == 404
    assert outsider_response.json()["error"]["code"] == "trip_not_found"
    assert remove_response.status_code == 200
    assert removed_response.status_code == 404
    assert removed_response.json()["error"]["code"] == "trip_not_found"
