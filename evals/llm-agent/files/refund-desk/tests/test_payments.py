import unittest

from app.payments import Payments
from app.store import seeded
from tests.fakes import FakeGateway


class PaymentsTest(unittest.TestCase):
    def test_refund_is_recorded(self):
        store = seeded()
        Payments(store, FakeGateway()).refund("o_1001", 49900)
        self.assertEqual(store.refunded_paise("o_1001"), 49900)

    def test_same_key_is_deduplicated_by_the_gateway(self):
        store = seeded()
        p = Payments(store, FakeGateway())
        a = p.refund("o_1001", 49900, idempotency_key="k1")
        b = p.refund("o_1001", 49900, idempotency_key="k1")
        self.assertEqual(a["id"], b["id"])


if __name__ == "__main__":
    unittest.main()
