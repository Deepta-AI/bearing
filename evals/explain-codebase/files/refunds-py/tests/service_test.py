import unittest

from refunds.errors import NotFound, OverRefund
from refunds.service import RefundService, needs_approval
from refunds.store import Store
from refunds.validation import RefundRequest


class NeedsApprovalTest(unittest.TestCase):
    def test_threshold_is_exclusive(self):
        self.assertFalse(needs_approval(500_000))
        self.assertTrue(needs_approval(500_001))


class CreateTest(unittest.TestCase):
    def setUp(self):
        self.store = Store(":memory:")
        self.store.add_order("ord_1", 900_000)
        self.service = RefundService(self.store)

    def test_small_refund_is_approved(self):
        out = self.service.create(RefundRequest("ord_1", 10_000, "damaged"))
        self.assertEqual(out["status"], "approved")

    def test_large_refund_waits_for_manager(self):
        out = self.service.create(RefundRequest("ord_1", 600_000, "wrong item"))
        self.assertEqual(out["status"], "awaiting_approval")

    def test_over_refund_is_refused(self):
        with self.assertRaises(OverRefund):
            self.service.create(RefundRequest("ord_1", 900_001, "x"))

    def test_unknown_order(self):
        with self.assertRaises(NotFound):
            self.service.create(RefundRequest("nope", 100, "x"))


if __name__ == "__main__":
    unittest.main()
