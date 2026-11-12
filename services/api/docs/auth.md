# Authentication Guide

This document explains the Phase 1 authentication flow for Lakbay.

## Purpose

Authentication lets the backend know who the user is and which records they are
allowed to access. This is required before building destinations, trips,
expenses, uploads, and group collaboration.

## Endpoints

```text
POST /api/v1/auth/register
POST /api/v1/auth/register/admin
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout

GET /api/v1/users/me
PATCH /api/v1/users/me
```

## Normal Registration

Request:

```json
{
  "full_name": "Juan Traveler",
  "email": "juan@example.com",
  "password": "password123",
  "confirm_password": "password123",
  "avatar_url": null
}
```

`confirm_password` is used only for request validation. It is not stored in the
database.

## Admin Registration

Admin registration is public but guarded by `ADMIN_REGISTRATION_CODE`.

Request:

```json
{
  "full_name": "Admin User",
  "email": "admin@example.com",
  "password": "password123",
  "confirm_password": "password123",
  "avatar_url": null,
  "admin_registration_code": "value-from-env"
}
```

Only trusted project admins should know the registration code.

## Login

Request:

```json
{
  "email": "juan@example.com",
  "password": "password123"
}
```

Login returns the user plus an access token and refresh token.

## Token Flow

- Access token: short-lived token for protected API requests.
- Refresh token: longer-lived token used to get a new access token.
- Logout: revokes the refresh token.

Send the access token in protected requests:

```text
Authorization: Bearer ACCESS_TOKEN
```

## Refresh Token Rotation

When Flutter calls:

```text
POST /api/v1/auth/refresh
```

the backend revokes the old refresh token and returns a new refresh token. This
means the old refresh token should be replaced in Flutter's secure storage.

## Avatar URL

`avatar_url` is optional in Phase 1. The actual Cloudinary upload endpoint will
be implemented later. For now, users can store a URL that was already uploaded or
provided by another service.

## Admin account directory

`GET /api/v1/admin/users` requires an administrator access token. Query parameters are `search` (optional name or email), `limit` (1–100, default 20), and `offset` (nonnegative). The response contains `total_users`, `matching_users`, `signed_in_users`, and a paginated `items` list. Each item contains user ID, name, email, role, account status, and `has_active_session`. It never contains password or token hashes.

`signed_in_users` counts distinct active accounts with at least one unrevoked, unexpired refresh token. Multiple sessions for one account count once. This is a valid-session count, not a live online-presence measurement. The list shows both active and inactive registered accounts. A traveler token receives 403; no token receives 401.
