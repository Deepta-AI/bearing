"""Settings read from the environment."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    paygate_base_url: str
    paygate_secret_key: str
    database_url: str


def load():
    return Settings(
        paygate_base_url=os.environ.get("PAYGATE_BASE_URL", "https://api.paygate.example"),
        paygate_secret_key=os.environ["PAYGATE_SECRET_KEY"],
        database_url=os.environ.get("DATABASE_URL", "sqlite:///payouts.db"),
    )
