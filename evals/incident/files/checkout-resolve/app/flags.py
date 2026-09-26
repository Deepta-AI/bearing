"""Feature flags, read from the environment (config/production.env in production)."""

import os


def _on(name: str, default: str) -> bool:
    return os.environ.get(name, default).strip().lower() in ("1", "true", "yes", "on")


def three_ds_v2() -> bool:
    """The 3DS v2 challenge flow for card payments; off means the classic flow."""
    return _on("PAYMENTS_3DS_V2_ENABLED", "true")
