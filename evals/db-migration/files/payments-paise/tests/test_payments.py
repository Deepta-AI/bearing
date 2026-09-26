import migrate
from app.payments import correct_amount, record_payment, record_refund, total_for_customer


def test_total_nets_refunds(conn):
    migrate.up_to(conn)
    conn.execute("INSERT INTO customers (id, email) VALUES (1, 'a@example.com')")
    record_payment(conn, 1, 250.0)
    record_payment(conn, 1, 99.5)
    record_refund(conn, 1, 50.0)
    assert total_for_customer(conn, 1) == 299.5


def test_total_skips_deleted_rows(conn):
    migrate.up_to(conn)
    conn.execute("INSERT INTO customers (id, email) VALUES (1, 'a@example.com')")
    pid = record_payment(conn, 1, 100.0)
    record_payment(conn, 1, 20.0)
    conn.execute("UPDATE payments SET deleted_at = '2026-09-01T00:00:00Z' WHERE id = ?", (pid,))
    assert total_for_customer(conn, 1) == 20.0


def test_correction_changes_the_total(conn):
    migrate.up_to(conn)
    conn.execute("INSERT INTO customers (id, email) VALUES (1, 'a@example.com')")
    pid = record_payment(conn, 1, 100.0)
    correct_amount(conn, pid, 110.0)
    assert total_for_customer(conn, 1) == 110.0
