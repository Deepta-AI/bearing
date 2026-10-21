import unittest

from shopapi.orders import Line, Order


class OrderTest(unittest.TestCase):
    def test_total_is_integer_paise(self):
        o = Order("O-1", [Line("TEA", 2, 12000), Line("CAKE", 1, 25050)])
        self.assertEqual(o.total_paise(), 49050)

    def test_json_carries_the_total(self):
        self.assertEqual(Order("O-2").to_json()["total_paise"], 0)
