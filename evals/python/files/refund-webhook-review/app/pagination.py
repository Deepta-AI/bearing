"""Opaque keyset cursors and the shared page shape (docs/api.md, Lists)."""

import base64
import binascii
import json
from typing import Annotated

from fastapi import Query
from pydantic import BaseModel

from app.errors import ValidationFailed

DEFAULT_LIMIT = 20
MAX_LIMIT = 100

Limit = Annotated[int, Query(ge=1, le=MAX_LIMIT)]
Cursor = Annotated[str | None, Query(max_length=200)]


def encode_cursor(sort_value: str, row_id: str) -> str:
    """The cursor that resumes after the row (sort_value, row_id)."""
    raw = json.dumps([sort_value, row_id]).encode()
    return base64.urlsafe_b64encode(raw).decode()


def decode_cursor(cursor: str) -> tuple[str, str]:
    """(sort_value, row_id) from a cursor, or ValidationFailed."""
    try:
        value = json.loads(base64.urlsafe_b64decode(cursor.encode()))
    except (binascii.Error, ValueError) as exc:
        raise ValidationFailed("cursor is invalid") from exc
    if not (isinstance(value, list) and len(value) == 2 and all(isinstance(v, str) for v in value)):
        raise ValidationFailed("cursor is invalid")
    return value[0], value[1]


class Page[T](BaseModel):
    """One page of a list."""

    items: list[T]
    next_cursor: str | None
