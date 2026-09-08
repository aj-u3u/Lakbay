import base64
import hashlib
import hmac
import json
import secrets
from datetime import UTC, datetime, timedelta
from typing import Any

from app.core.config import Settings, get_settings


PASSWORD_HASH_ALGORITHM = "pbkdf2_sha256"
PASSWORD_HASH_ITERATIONS = 600_000


class InvalidTokenError(Exception):
    pass


class ExpiredTokenError(InvalidTokenError):
    pass


def hash_password(password: str) -> str:
    salt = secrets.token_urlsafe(24)
    digest = _hash_password_digest(password, salt, PASSWORD_HASH_ITERATIONS)

    return (
        f"{PASSWORD_HASH_ALGORITHM}"
        f"${PASSWORD_HASH_ITERATIONS}"
        f"${salt}"
        f"${digest}"
    )


def verify_password(password: str, password_hash: str) -> bool:
    try:
        algorithm, iterations, salt, expected_digest = password_hash.split("$", 3)
    except ValueError:
        return False

    if algorithm != PASSWORD_HASH_ALGORITHM:
        return False

    try:
        parsed_iterations = int(iterations)
    except ValueError:
        return False

    actual_digest = _hash_password_digest(password, salt, parsed_iterations)

    return hmac.compare_digest(actual_digest, expected_digest)


def create_access_token(
    *,
    user_id: int,
    role: str,
    settings: Settings | None = None,
) -> str:
    resolved_settings = settings or get_settings()
    expires_delta = timedelta(
        minutes=resolved_settings.jwt_access_token_expire_minutes,
    )

    return create_jwt_token(
        subject=str(user_id),
        token_type="access",
        expires_delta=expires_delta,
        extra_claims={"role": role},
        settings=resolved_settings,
    )


def create_jwt_token(
    *,
    subject: str,
    token_type: str,
    expires_delta: timedelta,
    extra_claims: dict[str, Any] | None = None,
    settings: Settings | None = None,
) -> str:
    resolved_settings = settings or get_settings()
    secret = _require_jwt_secret(resolved_settings)
    now = datetime.now(UTC)
    expires_at = now + expires_delta
    header = {
        "alg": resolved_settings.jwt_algorithm,
        "typ": "JWT",
    }
    payload: dict[str, Any] = {
        "sub": subject,
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int(expires_at.timestamp()),
    }

    if extra_claims:
        payload.update(extra_claims)

    encoded_header = _json_b64url_encode(header)
    encoded_payload = _json_b64url_encode(payload)
    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    signature = _sign_jwt(signing_input, secret, resolved_settings.jwt_algorithm)

    return f"{encoded_header}.{encoded_payload}.{_b64url_encode(signature)}"


def decode_jwt_token(token: str, settings: Settings | None = None) -> dict[str, Any]:
    resolved_settings = settings or get_settings()
    secret = _require_jwt_secret(resolved_settings)

    try:
        encoded_header, encoded_payload, encoded_signature = token.split(".", 2)
    except ValueError as exc:
        raise InvalidTokenError("Token must contain three parts.") from exc

    try:
        header = json.loads(_b64url_decode(encoded_header))
        payload = json.loads(_b64url_decode(encoded_payload))
        signature = _b64url_decode(encoded_signature)
    except (ValueError, json.JSONDecodeError) as exc:
        raise InvalidTokenError("Token is not valid JSON.") from exc

    algorithm = header.get("alg")

    if algorithm != resolved_settings.jwt_algorithm:
        raise InvalidTokenError("Token algorithm does not match configuration.")

    signing_input = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    expected_signature = _sign_jwt(signing_input, secret, algorithm)

    if not hmac.compare_digest(signature, expected_signature):
        raise InvalidTokenError("Token signature is invalid.")

    expires_at = payload.get("exp")

    if not isinstance(expires_at, int):
        raise InvalidTokenError("Token expiration is missing.")

    if datetime.now(UTC).timestamp() >= expires_at:
        raise ExpiredTokenError("Token has expired.")

    return payload


def generate_refresh_token() -> str:
    return secrets.token_urlsafe(48)


def hash_refresh_token(refresh_token: str) -> str:
    return hashlib.sha256(refresh_token.encode("utf-8")).hexdigest()


def _hash_password_digest(password: str, salt: str, iterations: int) -> str:
    digest = hashlib.pbkdf2_hmac(
        "sha256",
        password.encode("utf-8"),
        salt.encode("utf-8"),
        iterations,
    )

    return base64.urlsafe_b64encode(digest).decode("utf-8")


def _require_jwt_secret(settings: Settings) -> str:
    if not settings.jwt_secret_key:
        raise RuntimeError("JWT_SECRET_KEY is required for authentication.")

    return settings.jwt_secret_key


def _sign_jwt(signing_input: bytes, secret: str, algorithm: str) -> bytes:
    if algorithm != "HS256":
        raise InvalidTokenError("Only HS256 is currently supported.")

    return hmac.new(
        secret.encode("utf-8"),
        signing_input,
        hashlib.sha256,
    ).digest()


def _json_b64url_encode(value: dict[str, Any]) -> str:
    payload = json.dumps(value, separators=(",", ":"), sort_keys=True).encode("utf-8")

    return _b64url_encode(payload)


def _b64url_encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _b64url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)

    return base64.urlsafe_b64decode(value + padding)
