# cartsvc

Cart totals for the shop checkout. Standard library only, Python 3.11+.

    make check

`shop/coupons.py` applies the coupon codes marketing keeps in
`data/coupons.json`; `shop/checkout.py` builds the cart total the payment
page shows. Money is `Decimal`, rounded half up to the paisa, the way the
invoices print it.

Marketing edits `data/coupons.json` by hand through the admin repo's merge
requests; checkout must keep working while they do. After each edit they run
`make coupon-report` to see what every code gives on a 2000 rupee cart.
