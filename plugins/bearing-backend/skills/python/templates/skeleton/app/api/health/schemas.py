"""Response models for the health routes."""

from typing import Literal

from pydantic import BaseModel


class HealthOut(BaseModel):
    """The process is up."""

    status: Literal["ok"]
    version: str


class ReadyOut(BaseModel):
    """Every dependency answered."""

    status: Literal["ok"]
    checks: dict[str, Literal["ok"]]
