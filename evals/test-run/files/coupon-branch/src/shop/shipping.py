"""Shipping charges."""

FREE_SHIPPING_FROM_PAISE = 99900
SHIPPING_PAISE = 4900


def shipping(subtotal_paise):
    if subtotal_paise >= FREE_SHIPPING_FROM_PAISE:
        return 0
    return SHIPPING_PAISE
