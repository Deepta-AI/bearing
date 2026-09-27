from dataclasses import dataclass
from datetime import date


@dataclass(frozen=True)
class Invoice:
    number: str
    customer: str
    issued_on: date
    amount_paise: int
