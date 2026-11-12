def _register(client, *, name: str, email: str, admin: bool = False) -> dict:
    path = "/api/v1/auth/register/admin" if admin else "/api/v1/auth/register"
    data = {
        "full_name": name,
        "email": email,
        "password": "password123",
        "confirm_password": "password123",
    }
    if admin:
        data["admin_registration_code"] = "admin-test-code"
    response = client.post(path, json=data)
    assert response.status_code == 201
    return response.json()


def test_admin_directory_counts_accounts_and_distinct_valid_sessions(client) -> None:
    admin = _register(client, name="Admin User", email="admin@example.com", admin=True)
    traveler = _register(client, name="Ana Traveler", email="ana@example.com")
    other = _register(client, name="Ben Traveler", email="ben@example.com")
    admin_headers = {"Authorization": f"Bearer {admin['tokens']['access_token']}"}
    traveler_headers = {"Authorization": f"Bearer {traveler['tokens']['access_token']}"}

    assert client.get("/api/v1/admin/users").status_code == 401
    assert client.get("/api/v1/admin/users", headers=traveler_headers).status_code == 403
    assert client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {other['tokens']['access_token']}"},
        json={"refresh_token": other["tokens"]["refresh_token"]},
    ).status_code == 200
    assert client.post(
        "/api/v1/auth/login",
        json={"email": "ana@example.com", "password": "password123"},
    ).status_code == 200

    response = client.get("/api/v1/admin/users", headers=admin_headers)
    assert response.status_code == 200
    body = response.json()
    assert body["total_users"] == 3
    assert body["matching_users"] == 3
    assert body["signed_in_users"] == 2  # Ana's two sessions count once.
    by_email = {item["email"]: item for item in body["items"]}
    assert by_email["ana@example.com"]["has_active_session"] is True
    assert by_email["ben@example.com"]["has_active_session"] is False
    assert "password_hash" not in by_email["ana@example.com"]

    filtered = client.get(
        "/api/v1/admin/users?search=ana&limit=1&offset=0", headers=admin_headers
    )
    assert filtered.status_code == 200
    assert filtered.json()["matching_users"] == 1
    assert filtered.json()["total_users"] == 3
    assert [item["email"] for item in filtered.json()["items"]] == [
        "ana@example.com"
    ]
