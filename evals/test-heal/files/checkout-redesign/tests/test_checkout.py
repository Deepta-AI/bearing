from tests.factories import cart_of, festival_coupon
from tests.pages.checkout_page import CheckoutPage
from app.cart import Cart


def test_primary_action_enabled_on_filled_cart():
    """TC-0101: a cart with items shows the primary checkout button, enabled."""
    button = CheckoutPage(cart_of(600, 600)).primary_button()
    assert not button.disabled


def test_primary_action_disabled_on_empty_cart():
    """TC-0102: an empty cart shows the primary checkout button disabled."""
    button = CheckoutPage(Cart()).primary_button()
    assert button.disabled


def test_primary_action_label():
    """TC-0107: the primary checkout action reads Pay now."""
    button = CheckoutPage(cart_of(600, 600)).primary_button()
    assert button.text == "Pay now"


def test_total_shown():
    """TC-0103: two items at 600 rupees total 1,200.00 with free shipping."""
    page = CheckoutPage(cart_of(600, 600))
    assert page.total() == "₹1,200.00"
    assert page.shipping() == "₹0.00"


def test_free_shipping_at_threshold():
    """TC-0104: a cart of exactly 500 rupees ships free."""
    page = CheckoutPage(cart_of(500))
    assert page.shipping() == "₹0.00"
    assert page.total() == "₹500.00"


def test_shipping_fee_below_threshold():
    """TC-0105: a cart of 499 rupees pays the 40 rupee fee."""
    page = CheckoutPage(cart_of(499))
    assert page.shipping() == "₹40.00"
    assert page.total() == "₹539.00"


def test_coupon_applies():
    """TC-0106: a valid 10 percent coupon on 1,200 rupees totals 1,080.00."""
    cart = cart_of(600, 600)
    assert cart.apply_coupon(festival_coupon())
    page = CheckoutPage(cart)
    assert page.coupon_applied() == "FEST10: 10% off"
    assert page.total() == "₹1,080.00"
