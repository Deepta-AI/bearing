"""Page object for the checkout page. Locators live here, once."""

from app.checkout import render_checkout
from tests.pages.dom import Page


class CheckoutPage:
    def __init__(self, cart):
        self.page = Page(render_checkout(cart))

    def primary_button(self):
        return self.page.by_id("pay-btn")

    def total(self) -> str:
        return self.page.by_id("order-total").text

    def shipping(self) -> str:
        return self.page.by_id("shipping-fee").text

    def coupon_applied(self) -> str:
        return self.page.by_id("coupon-applied").text
