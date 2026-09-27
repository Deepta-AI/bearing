import unittest
from decimal import Decimal

from shop.checkout import cart_total
from shop.coupons import CouponError, DefaultCouponValidator, discount_for, get_validator

COUPONS = {
    "WELCOME10": {"percent": "10", "min_subtotal": "0"},
    "FESTIVE25": {"percent": "25", "min_subtotal": "2000"},
}


class DiscountTest(unittest.TestCase):
    def test_percent_off(self):
        self.assertEqual(discount_for("WELCOME10", Decimal("450.00"), coupons=COUPONS), Decimal("45.00"))

    def test_code_is_case_and_space_insensitive(self):
        self.assertEqual(discount_for(" festive25 ", Decimal("2000.00"), coupons=COUPONS), Decimal("500.00"))

    def test_unknown_coupon(self):
        with self.assertRaisesRegex(CouponError, "unknown coupon NOPE"):
            discount_for("nope", Decimal("100.00"), coupons=COUPONS)

    def test_below_minimum(self):
        with self.assertRaisesRegex(CouponError, "FESTIVE25 needs a subtotal of at least 2000"):
            discount_for("FESTIVE25", Decimal("1999.99"), coupons=COUPONS)

    def test_reads_the_coupons_file_by_default(self):
        self.assertEqual(discount_for("WELCOME10", Decimal("100.00")), Decimal("10.00"))


class FactoryTest(unittest.TestCase):
    def test_get_validator_returns_default_validator(self):
        self.assertIsInstance(get_validator(COUPONS), DefaultCouponValidator)


class CheckoutTest(unittest.TestCase):
    def test_total_with_coupon(self):
        items = [{"price": "150.00", "qty": 2}, {"price": "150.00", "qty": 1}]
        self.assertEqual(cart_total(items, "WELCOME10"), (Decimal("450.00"), Decimal("45.00"), Decimal("405.00"), ""))

    def test_unknown_coupon_shows_message(self):
        _, discount, total, message = cart_total([{"price": "99.00", "qty": 1}], "BOGUS")
        self.assertEqual((discount, total, message), (Decimal("0.00"), Decimal("99.00"), "unknown coupon BOGUS"))


if __name__ == "__main__":
    unittest.main()
