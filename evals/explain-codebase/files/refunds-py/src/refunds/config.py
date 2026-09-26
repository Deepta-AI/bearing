import json
from dataclasses import dataclass
from pathlib import Path

CONFIG_PATH = Path(__file__).resolve().parents[2] / "config.json"


@dataclass(frozen=True)
class Config:
    db_path: str
    port: int
    razorpay_base_url: str
    worker_poll_seconds: int


def load(path: Path = CONFIG_PATH) -> Config:
    raw = json.loads(path.read_text())
    return Config(
        db_path=raw["db_path"],
        port=raw["port"],
        razorpay_base_url=raw["razorpay_base_url"],
        worker_poll_seconds=raw["worker_poll_seconds"],
    )
