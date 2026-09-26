"""Web settings, read once at start."""

import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    port: int
    log_level: str
    database_url: str
    session_secret: str
    smtp_host: str
    smtp_user: str
    smtp_password: str


def load():
    return Settings(
        port=int(os.getenv("PORT", "8000")),
        log_level=os.getenv("LOG_LEVEL", "info"),
        database_url=os.environ["DATABASE_URL"],
        session_secret=os.environ["SESSION_SECRET"],
        smtp_host=os.getenv("SMTP_HOST", "localhost"),
        smtp_user=os.getenv("SMTP_USER", ""),
        smtp_password=os.getenv("SMTP_PASSWORD", ""),
    )
