import unittest

from inventory.service import InventoryService, NotFound
from inventory.store import seeded


class ServiceTest(unittest.TestCase):
    def setUp(self):
        self.svc = InventoryService(seeded())

    def test_search(self):
        self.assertEqual(
            [s["sku"] for s in self.svc.search_skus("sheet")],
            ["TL-SHEET-DBL", "TL-SHEET-DBL-2"],
        )

    def test_stock(self):
        self.assertEqual(
            self.svc.get_stock("KS-BOTTLE-750"),
            {"BLR-1": 420, "PNQ-1": 130, "DEL-2": 0},
        )

    def test_unknown_sku(self):
        with self.assertRaises(NotFound):
            self.svc.get_stock("NOPE")

    def test_duplicate_entry_has_no_history(self):
        self.assertEqual(self.svc.movements("TL-SHEET-DBL-2"), [])

    def test_archive(self):
        self.svc.archive_sku("TL-TOWEL-BATH")
        self.assertTrue(self.svc.get_sku("TL-TOWEL-BATH")["archived"])


if __name__ == "__main__":
    unittest.main()
