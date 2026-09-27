"""API key authentication: every key belongs to exactly one organisation."""

import hashlib
from typing import Annotated

from fastapi import Depends, Header, HTTPException

from app.db import Database, get_db


def hash_key(key: str) -> str:
    return hashlib.sha256(key.encode()).hexdigest()


async def current_org_id(
    db: Annotated[Database, Depends(get_db)],
    authorization: Annotated[str | None, Header()] = None,
) -> str:
    """The organisation of the calling API key, or 401."""
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="missing bearer token")
    row = await db.fetch_one(
        "SELECT org_id FROM api_keys WHERE key_hash = ?",
        (hash_key(authorization.removeprefix("Bearer ")),),
    )
    if row is None:
        raise HTTPException(status_code=401, detail="unknown api key")
    org_id: str = row["org_id"]
    return org_id


OrgId = Annotated[str, Depends(current_org_id)]
