import unittest

from refunds.bulk import import_rows
from refunds.store import Store


class ImportTest(unittest.TestCase):
    def test_rows_become_refunds(self):
        store = Store(":memory:")
        rows = [
            {"order_id": "ord_1", "amount": "250", "reason": " damaged "},
            {"order_id": "ord_2", "amount": "7500", "reason": "wrong item"},
        ]
        self.assertEqual(import_rows(store, rows), 2)
        statuses = [r["status"] for r in store.data["refunds"]]
        self.assertEqual(statuses, ["approved", "awaiting_approval"])
        self.assertEqual(store.data["refunds"][1]["amount_paise"], 750_000)


if __name__ == "__main__":
    unittest.main()
