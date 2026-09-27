"""Print the discount each coupon in data/coupons.json gives on a sample cart.

Marketing runs `make coupon-report` after editing the coupons file.
"""

from decimal import Decimal

from shop.coupons import discount_for, load_coupons

SAMPLE_SUBTOTAL = Decimal("2000.00")


def main():
    for code in sorted(load_coupons()):
        print(code, discount_for(code, SAMPLE_SUBTOTAL, True))


if __name__ == "__main__":
    main()
