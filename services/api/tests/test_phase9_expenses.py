from itertools import count

import pytest


ADMIN_COUNTER = count(1)


DESTINATION = {
    "name": "Expense Test Stop",
    "description": "A destination for expense tests.",
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
            "full_name": "Expense Admin",
            "email": f"expense-admin-{admin_index}@example.com",
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


def create_trip(client, headers: dict[str, str], *, total_budget: str = "100.00") -> dict:
    destination = create_destination(client)
    response = client.post(
        "/api/v1/trips",
        headers=headers,
        json={
            "title": "Shared Expense Trip",
            "description": "A shared test trip.",
            "traveler_count": 2,
            "total_budget": total_budget,
            "estimated_total_cost": "25.00",
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
    amount: str = "90.00",
    category: str = "meals",
) -> dict:
    response = client.post(
        f"/api/v1/trips/{trip_id}/expenses",
        headers=headers,
        json={
            "title": "Group meal",
            "description": "Shared lunch.",
            "category": category,
            "amount": amount,
            "paid_by_trip_member_id": paid_by_trip_member_id,
            "expense_date": "2026-10-10",
            "notes": "Paid in cash.",
        },
    )

    assert response.status_code == 201

    return response.json()


def test_expenses_require_authentication(client) -> None:
    response = client.get("/api/v1/trips/1/expenses")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_outsider_and_removed_member_cannot_access_expenses(client) -> None:
    owner_headers = register_user(client, email="expense-owner-access@example.com")
    member_headers = register_user(client, email="expense-member-access@example.com")
    outsider_headers = register_user(client, email="expense-outsider-access@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-access@example.com",
    )

    outsider_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/expenses",
        headers=outsider_headers,
    )
    remove_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/members/{member['trip_member_id']}",
        headers=owner_headers,
    )
    removed_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/expenses",
        headers=member_headers,
    )

    assert outsider_response.status_code == 404
    assert outsider_response.json()["error"]["code"] == "trip_not_found"
    assert remove_response.status_code == 200
    assert removed_response.status_code == 404
    assert removed_response.json()["error"]["code"] == "trip_not_found"


def test_member_can_create_own_expense_with_equal_splits(client) -> None:
    owner_headers = register_user(client, email="expense-owner-equal@example.com")
    member_headers = register_user(client, email="expense-member-equal@example.com")
    third_headers = register_user(client, email="expense-third-equal@example.com")
    trip = create_trip(client, owner_headers)
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-equal@example.com",
    )
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-third-equal@example.com",
    )

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/expenses",
        headers=member_headers,
        json={
            "title": "Shared snack",
            "category": "meals",
            "amount": "10.00",
            "paid_by_trip_member_id": member["trip_member_id"],
            "expense_date": "2026-10-10",
        },
    )
    body = response.json()
    shares = [split["share_amount"] for split in body["splits"]]
    third_list_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/expenses",
        headers=third_headers,
    )

    assert response.status_code == 201
    assert body["split_method"] == "equal"
    assert shares == ["3.34", "3.33", "3.33"]
    assert third_list_response.status_code == 200
    assert third_list_response.json()[0]["trip_expense_id"] == body["trip_expense_id"]


def test_member_cannot_create_expense_paid_by_another_member(client) -> None:
    owner_headers = register_user(client, email="expense-owner-payer@example.com")
    member_headers = register_user(client, email="expense-member-payer@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-payer@example.com",
    )
    owner_member_id = trip["members"][0]["trip_member_id"]

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/expenses",
        headers=member_headers,
        json={
            "title": "Invalid payer",
            "category": "other",
            "amount": "50.00",
            "paid_by_trip_member_id": owner_member_id,
        },
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "expense_payer_permission_denied"


def test_organizer_can_create_expense_paid_by_another_member(client) -> None:
    owner_headers = register_user(client, email="expense-owner-organizer@example.com")
    organizer_headers = register_user(client, email="expense-organizer@example.com")
    register_user(client, email="expense-member-by-organizer@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-organizer@example.com",
        role="organizer",
    )
    member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-by-organizer@example.com",
    )

    response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/expenses",
        headers=organizer_headers,
        json={
            "title": "Van rental",
            "category": "transportation",
            "amount": "300.00",
            "paid_by_trip_member_id": member["trip_member_id"],
        },
    )

    assert response.status_code == 201
    assert response.json()["paid_by_trip_member_id"] == member["trip_member_id"]


@pytest.mark.parametrize(
    "payload",
    [
        {"title": None},
        {"category": None},
        {"amount": None},
        {"paid_by_trip_member_id": None},
        {"expense_date": None},
    ],
)
def test_update_rejects_null_required_fields(client, payload: dict) -> None:
    owner_headers = register_user(client, email="expense-owner-null-update@example.com")
    trip = create_trip(client, owner_headers)
    expense = create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=trip["members"][0]["trip_member_id"],
        amount="20.00",
    )

    response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=owner_headers,
        json=payload,
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_member_cannot_update_or_void_another_members_expense(client) -> None:
    owner_headers = register_user(client, email="expense-owner-edit-denied@example.com")
    creator_headers = register_user(client, email="expense-creator-edit-denied@example.com")
    other_headers = register_user(client, email="expense-other-edit-denied@example.com")
    trip = create_trip(client, owner_headers)
    creator = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-creator-edit-denied@example.com",
    )
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-other-edit-denied@example.com",
    )
    expense = create_expense(
        client,
        headers=creator_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=creator["trip_member_id"],
        amount="60.00",
    )

    update_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=other_headers,
        json={"amount": "70.00"},
    )
    void_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=other_headers,
    )

    assert update_response.status_code == 403
    assert update_response.json()["error"]["code"] == "expense_permission_denied"
    assert void_response.status_code == 403
    assert void_response.json()["error"]["code"] == "expense_permission_denied"


def test_expense_summary_calculates_breakdown_and_balances(client) -> None:
    owner_headers = register_user(client, email="expense-owner-summary@example.com")
    register_user(client, email="expense-member-summary-a@example.com")
    register_user(client, email="expense-member-summary-b@example.com")
    trip = create_trip(client, owner_headers, total_budget="100.00")
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-summary-a@example.com",
    )
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-summary-b@example.com",
    )
    owner_member_id = trip["members"][0]["trip_member_id"]
    create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=owner_member_id,
        amount="90.00",
    )

    response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/expenses/summary",
        headers=owner_headers,
    )
    body = response.json()
    owner_balance = body["member_balances"][0]

    assert response.status_code == 200
    assert body["total_spent"] == "90.00"
    assert body["remaining_budget"] == "10.00"
    assert body["over_budget_amount"] == "0.00"
    assert body["is_over_budget"] is False
    assert body["category_breakdown"] == [{"category": "meals", "total": "90.00"}]
    assert owner_balance["paid_total"] == "90.00"
    assert owner_balance["share_total"] == "30.00"
    assert owner_balance["net_balance"] == "60.00"
    assert [balance["net_balance"] for balance in body["member_balances"][1:]] == [
        "-30.00",
        "-30.00",
    ]


def test_expense_summary_keeps_removed_members_with_existing_splits(client) -> None:
    owner_headers = register_user(client, email="expense-owner-removed-summary@example.com")
    register_user(client, email="expense-member-removed-summary@example.com")
    trip = create_trip(client, owner_headers, total_budget="100.00")
    removed_member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-removed-summary@example.com",
    )
    create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=trip["members"][0]["trip_member_id"],
        amount="20.00",
    )

    remove_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/members/{removed_member['trip_member_id']}",
        headers=owner_headers,
    )
    summary_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/expenses/summary",
        headers=owner_headers,
    )
    balances_by_email = {
        balance["email"]: balance
        for balance in summary_response.json()["member_balances"]
    }

    assert remove_response.status_code == 200
    assert summary_response.status_code == 200
    assert balances_by_email["expense-owner-removed-summary@example.com"][
        "net_balance"
    ] == "10.00"
    assert balances_by_email["expense-member-removed-summary@example.com"][
        "net_balance"
    ] == "-10.00"


def test_amount_update_preserves_removed_member_existing_split(client) -> None:
    owner_headers = register_user(client, email="expense-owner-removed-update@example.com")
    register_user(client, email="expense-member-removed-update@example.com")
    trip = create_trip(client, owner_headers, total_budget="100.00")
    removed_member = add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-removed-update@example.com",
    )
    expense = create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=trip["members"][0]["trip_member_id"],
        amount="20.00",
    )
    remove_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/members/{removed_member['trip_member_id']}",
        headers=owner_headers,
    )

    update_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=owner_headers,
        json={"amount": "30.00"},
    )
    body = update_response.json()
    splits_by_email = {
        split["email"]: split
        for split in body["splits"]
    }

    assert remove_response.status_code == 200
    assert update_response.status_code == 200
    assert len(body["splits"]) == 2
    assert splits_by_email["expense-owner-removed-update@example.com"][
        "share_amount"
    ] == "15.00"
    assert splits_by_email["expense-member-removed-update@example.com"][
        "share_amount"
    ] == "15.00"


def test_updating_amount_regenerates_splits(client) -> None:
    owner_headers = register_user(client, email="expense-owner-update@example.com")
    register_user(client, email="expense-member-update-a@example.com")
    register_user(client, email="expense-member-update-b@example.com")
    trip = create_trip(client, owner_headers)
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-update-a@example.com",
    )
    add_member(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        email="expense-member-update-b@example.com",
    )
    expense = create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=trip["members"][0]["trip_member_id"],
        amount="9.00",
    )

    response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=owner_headers,
        json={"amount": "10.00"},
    )

    assert response.status_code == 200
    assert [split["share_amount"] for split in response.json()["splits"]] == [
        "3.34",
        "3.33",
        "3.33",
    ]


def test_voided_expense_is_excluded_from_summary(client) -> None:
    owner_headers = register_user(client, email="expense-owner-void@example.com")
    trip = create_trip(client, owner_headers)
    expense = create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=trip["members"][0]["trip_member_id"],
        amount="40.00",
    )

    void_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=owner_headers,
    )
    summary_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/expenses/summary",
        headers=owner_headers,
    )
    list_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/expenses",
        headers=owner_headers,
    )
    list_voided_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/expenses",
        headers=owner_headers,
        params={"include_voided": True},
    )

    assert void_response.status_code == 200
    assert void_response.json()["status"] == "voided"
    assert summary_response.status_code == 200
    assert summary_response.json()["total_spent"] == "0.00"
    assert list_response.json() == []
    assert list_voided_response.json()[0]["status"] == "voided"


def test_archived_trip_rejects_expense_writes(client) -> None:
    owner_headers = register_user(client, email="expense-owner-archived@example.com")
    trip = create_trip(client, owner_headers)
    expense = create_expense(
        client,
        headers=owner_headers,
        trip_id=trip["trip_id"],
        paid_by_trip_member_id=trip["members"][0]["trip_member_id"],
        amount="40.00",
    )
    archive_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/archive",
        headers=owner_headers,
    )

    create_response = client.post(
        f"/api/v1/trips/{trip['trip_id']}/expenses",
        headers=owner_headers,
        json={
            "title": "Late expense",
            "category": "other",
            "amount": "10.00",
            "paid_by_trip_member_id": trip["members"][0]["trip_member_id"],
        },
    )
    update_response = client.patch(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=owner_headers,
        json={"amount": "45.00"},
    )
    void_response = client.delete(
        f"/api/v1/trips/{trip['trip_id']}/expenses/{expense['trip_expense_id']}",
        headers=owner_headers,
    )
    summary_response = client.get(
        f"/api/v1/trips/{trip['trip_id']}/expenses/summary",
        headers=owner_headers,
    )

    assert archive_response.status_code == 200
    assert create_response.status_code == 400
    assert create_response.json()["error"]["code"] == "trip_archived_read_only"
    assert update_response.status_code == 400
    assert update_response.json()["error"]["code"] == "trip_archived_read_only"
    assert void_response.status_code == 400
    assert void_response.json()["error"]["code"] == "trip_archived_read_only"
    assert summary_response.status_code == 200
