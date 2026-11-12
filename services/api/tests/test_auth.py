def test_register_user_returns_tokens(client) -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Juan Traveler",
            "email": "JUAN@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )

    assert response.status_code == 201
    body = response.json()
    assert body["user"]["email"] == "juan@example.com"
    assert body["user"]["role"] == "user"
    assert body["tokens"]["token_type"] == "bearer"
    assert body["tokens"]["access_token"]
    assert body["tokens"]["refresh_token"]


def test_register_requires_matching_password_confirmation(client) -> None:
    response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Juan Traveler",
            "email": "juan@example.com",
            "password": "password123",
            "confirm_password": "password456",
        },
    )

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "validation_error"


def test_register_rejects_duplicate_email(client) -> None:
    payload = {
        "full_name": "Juan Traveler",
        "email": "juan@example.com",
        "password": "password123",
        "confirm_password": "password123",
    }

    assert client.post("/api/v1/auth/register", json=payload).status_code == 201

    response = client.post("/api/v1/auth/register", json=payload)

    assert response.status_code == 409
    assert response.json()["error"]["code"] == "email_already_registered"


def test_register_admin_requires_admin_code(client) -> None:
    response = client.post(
        "/api/v1/auth/register/admin",
        json={
            "full_name": "Admin User",
            "email": "admin@example.com",
            "password": "password123",
            "confirm_password": "password123",
            "admin_registration_code": "wrong-code",
        },
    )

    assert response.status_code == 403
    assert response.json()["error"]["code"] == "invalid_admin_registration_code"


def test_register_admin_returns_admin_user(client) -> None:
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

    assert response.status_code == 201
    assert response.json()["user"]["role"] == "admin"


def test_login_with_json_body(client) -> None:
    client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Juan Traveler",
            "email": "juan@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )

    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "juan@example.com",
            "password": "password123",
        },
    )

    assert response.status_code == 200
    assert response.json()["tokens"]["access_token"]


def test_login_rejects_wrong_password(client) -> None:
    client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Juan Traveler",
            "email": "juan@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )

    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "juan@example.com",
            "password": "wrong-password",
        },
    )

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "invalid_credentials"


def test_get_me_requires_access_token(client) -> None:
    response = client.get("/api/v1/users/me")

    assert response.status_code == 401
    assert response.json()["error"]["code"] == "not_authenticated"


def test_get_me_returns_current_user(client) -> None:
    register_response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Juan Traveler",
            "email": "juan@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )
    access_token = register_response.json()["tokens"]["access_token"]

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {access_token}"},
    )

    assert response.status_code == 200
    assert response.json()["email"] == "juan@example.com"


def test_update_me_accepts_avatar_url(client) -> None:
    register_response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Juan Traveler",
            "email": "juan@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )
    access_token = register_response.json()["tokens"]["access_token"]

    response = client.patch(
        "/api/v1/users/me",
        headers={"Authorization": f"Bearer {access_token}"},
        json={
            "full_name": "Juan Dela Cruz",
            "avatar_url": "https://res.cloudinary.com/demo/image/upload/avatar.jpg",
        },
    )

    assert response.status_code == 200
    assert response.json()["full_name"] == "Juan Dela Cruz"
    assert response.json()["avatar_url"].startswith("https://res.cloudinary.com")


def test_refresh_rotates_refresh_token(client) -> None:
    register_response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Juan Traveler",
            "email": "juan@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )
    original_refresh_token = register_response.json()["tokens"]["refresh_token"]

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": original_refresh_token},
    )

    assert refresh_response.status_code == 200
    assert refresh_response.json()["tokens"]["refresh_token"] != original_refresh_token

    second_refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": original_refresh_token},
    )

    assert second_refresh_response.status_code == 401
    assert second_refresh_response.json()["error"]["code"] == "invalid_refresh_token"


def test_logout_revokes_refresh_token(client) -> None:
    register_response = client.post(
        "/api/v1/auth/register",
        json={
            "full_name": "Juan Traveler",
            "email": "juan@example.com",
            "password": "password123",
            "confirm_password": "password123",
        },
    )
    body = register_response.json()
    access_token = body["tokens"]["access_token"]
    refresh_token = body["tokens"]["refresh_token"]

    logout_response = client.post(
        "/api/v1/auth/logout",
        headers={"Authorization": f"Bearer {access_token}"},
        json={"refresh_token": refresh_token},
    )

    assert logout_response.status_code == 200
    assert logout_response.json()["message"] == "Logged out successfully."

    refresh_response = client.post(
        "/api/v1/auth/refresh",
        json={"refresh_token": refresh_token},
    )

    assert refresh_response.status_code == 401
