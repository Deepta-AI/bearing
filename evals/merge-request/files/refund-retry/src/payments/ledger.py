"""An append-only ledger of money movements."""

import csv
import io
from dataclasses import dataclass


@dataclass(frozen=True)
class Entry:
    order_id: str
    kind: str
    amount_paise: int


class Ledger:
    def __init__(self):
        self.entries = []

    def record(self, order_id, kind, amount_paise):
        self.entries.append(Entry(order_id, kind, amount_paise))

    def balance(self, order_id):
        total = 0
        for e in self.entries:
            if e.order_id == order_id:
                total += e.amount_paise if e.kind == "capture" else -e.amount_paise
        return total

    def export_csv(self):
        out = io.StringIO()
        w = csv.writer(out)
        w.writerow(["order_id", "kind", "amount_paise"])
        for e in self.entries:
            w.writerow([e.order_id, e.kind, e.amount_paise])
        return out.getvalue()
