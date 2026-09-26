from datetime import datetime, timezone

from app.db.invoice_repo import InvoiceRow
from app.services.invoices import PAGE_SIZE, InvoiceService
from tests.fakes import FakeConn


def test_create_uses_next_number_in_one_transaction():
    conn = FakeConn(results=[[(8,)], [(501,)]])
    invoice_id, number = InvoiceService(conn).create(7, 3, 12500, "EUR")
    assert (invoice_id, number) == (501, 8)
    assert conn.transactions == 1
    insert_sql, insert_params = conn.executed[1]
    assert insert_sql.startswith("INSERT INTO invoices")
    assert insert_params == (7, 3, 8, 12500, "EUR")


def test_list_page_maps_page_to_offset():
    issued = datetime(2026, 9, 1, tzinfo=timezone.utc)
    conn = FakeConn(results=[[(1, 10, "sent", 900, "EUR", issued)]])
    rows = InvoiceService(conn).list_page(7, 3)
    assert rows == [InvoiceRow(1, 10, "sent", 900, "EUR", issued)]
    sql, params = conn.executed[0]
    assert "ORDER BY issued_at DESC, id DESC" in sql
    assert params == (7, None, None, PAGE_SIZE, 2 * PAGE_SIZE)


def test_list_page_filters_status():
    conn = FakeConn(results=[[]])
    InvoiceService(conn).list_page(7, 1, status="paid")
    _, params = conn.executed[0]
    assert params == (7, "paid", "paid", PAGE_SIZE, 0)
