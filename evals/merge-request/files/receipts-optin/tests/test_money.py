import unittest

from receipts.money import rupees


class RupeesTest(unittest.TestCase):
    def test_two_decimals(self):
        self.assertEqual(rupees(480050), "4800.50")

    def test_small_and_negative(self):
        self.assertEqual(rupees(5), "0.05")
        self.assertEqual(rupees(-150), "-1.50")
