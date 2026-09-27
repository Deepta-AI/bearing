"""Domain errors and the one place they become HTTP responses."""

from fastapi import FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse


class DomainError(Exception):
    """Base of every error a service raises on purpose."""

    status_code = 400
    code = "bad_request"


class NotFoundError(DomainError):
    status_code = 404
    code = "not_found"


class ValidationFailed(DomainError):
    status_code = 422
    code = "validation_failed"


def _body(code: str, message: str, details: object = None) -> dict[str, object]:
    error: dict[str, object] = {"code": code, "message": message}
    if details is not None:
        error["details"] = details
    return {"error": error}


def register_exception_handlers(app: FastAPI) -> None:
    """Map DomainError and validation failures to the error envelope."""

    @app.exception_handler(DomainError)
    async def domain_error(_: Request, exc: DomainError) -> JSONResponse:
        return JSONResponse(_body(exc.code, str(exc)), status_code=exc.status_code)

    @app.exception_handler(RequestValidationError)
    async def validation_error(_: Request, exc: RequestValidationError) -> JSONResponse:
        return JSONResponse(
            _body("validation_failed", "request is invalid", jsonable_encoder(exc.errors())),
            status_code=422,
        )
