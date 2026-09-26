"""The order total: coupons first, then shipping on what is left."""

from shop import coupons as coupon_rules
from shop.shipping import shipping


def order_total(subtotal_paise, coupons=()):
    discounted = coupon_rules.apply(subtotal_paise, list(coupons))
    return discounted + shipping(discounted)
