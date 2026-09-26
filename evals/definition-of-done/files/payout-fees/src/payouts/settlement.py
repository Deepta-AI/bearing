"""Turn a batch of order lines into one payout per seller."""

from dataclasses import dataclass

from payouts.fees import platform_fee


@dataclass(frozen=True)
class Line:
    order_id: str
    seller_id: str
    amount_paise: int
    rate_bps: int


@dataclass(frozen=True)
class Payout:
    seller_id: str
    gross_paise: int
    fee_paise: int

    @property
    def net_paise(self) -> int:
        return self.gross_paise - self.fee_paise


def settle(lines, held_sellers=frozenset()):
    """One Payout per seller, in seller id order.

    Sellers in held_sellers are left out (their lines stay unsettled and are
    picked up by the next run). The fee is the sum of the line fees
    (ADR 0003), never a fee on the total.
    """
    gross = {}
    fees = {}
    for line in lines:
        if line.amount_paise < 0:
            raise ValueError(f"negative amount on order {line.order_id}")
        if line.seller_id in held_sellers:
            continue
        gross[line.seller_id] = gross.get(line.seller_id, 0) + line.amount_paise
        fee = platform_fee(line.amount_paise, line.rate_bps)
        fees[line.seller_id] = fees.get(line.seller_id, 0) + fee
    payouts = []
    for seller_id in sorted(gross):
        payouts.append(Payout(seller_id, gross[seller_id], fees[seller_id]))
    return payouts
