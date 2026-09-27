"""Build the nightly payout batch for merchants."""

from dataclasses import dataclass

MIN_PAYOUT_PAISE = 10_000  # below Rs 100 the balance rolls to the next batch


@dataclass(frozen=True)
class Balance:
    merchant_id: str
    settled_paise: int
    held_paise: int


def payable(b: Balance) -> int:
    amount = b.settled_paise - b.held_paise
    return amount if amount >= MIN_PAYOUT_PAISE else 0


def build_batch(balances: list[Balance]) -> list[tuple[str, int]]:
    return [(b.merchant_id, p) for b in balances if (p := payable(b)) > 0]
