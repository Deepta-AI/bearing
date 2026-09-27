from app.accounts import sign_up
from app.orders import add_address, place_order


def test_order_gets_an_invoice_with_billing_details(db):
    uid = sign_up(db, "ravi@example.com", "Ravi Kumar", "pw-12345")
    add_address(db, uid, "12 Lake Road", "Pune", "411001")
    order_id = place_order(db, uid, 149900)
    inv = db.execute("SELECT * FROM invoices WHERE order_id = ?", (order_id,)).fetchone()
    assert inv["billing_name"] == "Ravi Kumar"
    assert inv["billing_address"] == "12 Lake Road, Pune 411001"
    assert inv["total_paise"] == 149900
