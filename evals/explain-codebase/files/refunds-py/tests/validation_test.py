import unittest

from refunds.validation import parse


class ParseTest(unittest.TestCase):
    def test_flags_large_refund(self):
        req = parse({"order_id": "ord_1", "amount_paise": 500000, "reason": "x"})
        self.assertIn("needs_manager", req.flags)

    def test_rejects_zero(self):
        with self.assertRaises(ValueError):
            parse({"order_id": "ord_1", "amount_paise": 0})


if __name__ == "__main__":
    unittest.main()
