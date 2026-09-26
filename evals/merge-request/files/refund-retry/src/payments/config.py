import os
from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    gateway_url: str
    gateway_timeout_s: float
    refund_max_attempts: int
    refund_backoff_ms: int


def load_settings(env=None):
    env = os.environ if env is None else env
    return Settings(
        gateway_url=env.get("GATEWAY_URL", "http://localhost:9000"),
        gateway_timeout_s=float(env.get("GATEWAY_TIMEOUT_S", "10")),
        refund_max_attempts=int(env.get("REFUND_MAX_ATTEMPTS", "3")),
        refund_backoff_ms=int(env.get("REFUND_BACKOFF_MS", "200")),
    )
