from dataclasses import dataclass


@dataclass(frozen=True)
class Principal:
    """The authenticated caller, set by the API gateway in front of us."""

    user_id: int
    merchant_id: int
    role: str  # "admin", "support" or "viewer"
