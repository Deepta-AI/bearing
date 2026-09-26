import sys
import unittest

sys.path.insert(0, "src")
from ledger import balance  # noqa: E402


class BalanceTest(unittest.TestCase):
    def test_sums_cents(self):
        self.assertEqual(balance([{"cents": 150}, {"cents": -50}]), 100)


if __name__ == "__main__":
    unittest.main()
