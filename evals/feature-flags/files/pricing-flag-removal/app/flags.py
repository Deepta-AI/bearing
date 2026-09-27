"""The only reader of feature flag values. Every flag defaults off.

Values come from FLAG_<NAME> in the environment (one env file per region
under deploy/). Per-account overrides in config/flag_overrides.json win over
the environment for that account while their `until` date has not passed.
"""

import json
import os
from datetime import date
from enum import Enum
from pathlib import Path

OVERRIDES = Path(__file__).resolve().parent.parent / "config" / "flag_overrides.json"


class Flag(str, Enum):
    NEW_PRICING = "new_pricing"
    BULK_INVOICE_DOWNLOAD = "bulk_invoice_download"


def _env_name(flag: Flag) -> str:
    return "FLAG_" + flag.value.upper()


def load_overrides(path: Path = OVERRIDES) -> dict:
    with open(path, encoding="utf-8") as f:
        return json.load(f)


class Flags:
    def __init__(self, values: dict[Flag, bool] | None = None):
        self._values = dict(values or {})

    @classmethod
    def from_env(cls, environ=os.environ) -> "Flags":
        return cls({f: environ.get(_env_name(f), "").strip().lower() == "true" for f in Flag})

    def for_account(self, account_id: str, overrides: dict | None = None, today: date | None = None) -> "Flags":
        """These flags with the account's live overrides applied."""
        today = today or date.today()
        data = load_overrides() if overrides is None else overrides
        values = dict(self._values)
        for entry in data.get(account_id, []):
            if date.fromisoformat(entry["until"]) < today:
                continue
            values[Flag(entry["flag"])] = bool(entry["on"])
        return Flags(values)

    def enabled(self, flag: Flag) -> bool:
        return self._values.get(flag, False)

    def for_client(self) -> dict[str, bool]:
        """Flags the browser needs, serialised into the page as window.FLAGS."""
        return {Flag.NEW_PRICING.value: self.enabled(Flag.NEW_PRICING)}
