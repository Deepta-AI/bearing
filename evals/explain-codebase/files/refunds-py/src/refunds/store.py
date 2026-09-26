import json
import threading
from pathlib import Path


class Store:
    """Orders and refunds kept in one JSON file; ':memory:' keeps them in memory only."""

    def __init__(self, path: str):
        self.path = None if path == ":memory:" else Path(path)
        self.lock = threading.Lock()
        self.data = {"orders": {}, "refunds": []}
        if self.path and self.path.exists():
            self.data = json.loads(self.path.read_text())

    def _save(self) -> None:
        if self.path:
            self.path.write_text(json.dumps(self.data))

    def add_order(self, order_id: str, paid_paise: int) -> None:
        with self.lock:
            self.data["orders"][order_id] = paid_paise
            self._save()

    def paid(self, order_id: str):
        return self.data["orders"].get(order_id)

    def refunded(self, order_id: str) -> int:
        return sum(
            r["amount_paise"]
            for r in self.data["refunds"]
            if r["order_id"] == order_id and r["status"] != "rejected"
        )

    def insert_refund(self, order_id: str, amount_paise: int, reason: str, status: str) -> int:
        with self.lock:
            refund_id = len(self.data["refunds"]) + 1
            self.data["refunds"].append(
                {"id": refund_id, "order_id": order_id, "amount_paise": amount_paise,
                 "reason": reason, "status": status}
            )
            self._save()
            return refund_id

    def approved(self) -> list[tuple]:
        return [
            (r["id"], r["order_id"], r["amount_paise"])
            for r in self.data["refunds"]
            if r["status"] == "approved"
        ]

    def set_status(self, refund_id: int, status: str) -> None:
        with self.lock:
            self.data["refunds"][refund_id - 1]["status"] = status
            self._save()
