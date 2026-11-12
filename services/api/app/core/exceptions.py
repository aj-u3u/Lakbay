import logging
from http import HTTPStatus
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


logger = logging.getLogger(__name__)


class LakbayAPIError(Exception):
    def __init__(
        self,
        message: str,
        *,
        code: str = "bad_request",
        status_code: int = status.HTTP_400_BAD_REQUEST,
        details: Any | None = None,
        headers: dict[str, str] | None = None,
    ) -> None:
        self.message = message
        self.code = code
        self.status_code = status_code
        self.details = details
        self.headers = headers


def build_error_content(
    *,
    code: str,
    message: str,
    details: Any | None = None,
) -> dict[str, Any]:
    error: dict[str, Any] = {
        "code": code,
        "message": message,
    }

    if details is not None:
        error["details"] = details

    return {"error": error}


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(LakbayAPIError)
    async def lakbay_api_error_handler(
        request: Request,
        exc: LakbayAPIError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            headers=exc.headers,
            content=build_error_content(
                code=exc.code,
                message=exc.message,
                details=jsonable_encoder(exc.details),
            ),
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(
        request: Request,
        exc: StarletteHTTPException,
    ) -> JSONResponse:
        message = exc.detail if isinstance(exc.detail, str) else "Request failed."

        return JSONResponse(
            status_code=exc.status_code,
            headers=exc.headers,
            content=build_error_content(
                code=_status_code_to_error_code(exc.status_code),
                message=message,
                details=exc.detail if isinstance(exc.detail, dict) else None,
            ),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(
        request: Request,
        exc: RequestValidationError,
    ) -> JSONResponse:
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content=build_error_content(
                code="validation_error",
                message="Request validation failed.",
                details=jsonable_encoder(exc.errors()),
            ),
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(
        request: Request,
        exc: Exception,
    ) -> JSONResponse:
        logger.exception("Unhandled API error", exc_info=exc)

        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=build_error_content(
                code="internal_server_error",
                message="An unexpected server error occurred.",
            ),
        )


def _status_code_to_error_code(status_code: int) -> str:
    try:
        phrase = HTTPStatus(status_code).phrase
    except ValueError:
        return "http_error"

    return phrase.lower().replace(" ", "_").replace("-", "_")
