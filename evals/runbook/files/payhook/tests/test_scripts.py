from app import db, queue
from scripts import replay_dead


def test_replay_filters_by_error_and_dry_run():
    conn = db.connect("sqlite://")
    for i, err in enumerate(["signature_invalid", "signature_invalid", "orders_api_503"]):
        queue.enqueue(conn, f"evt_{i}", "payment.succeeded", "{}", now=100 + i)
        conn.execute("UPDATE events SET status='dead', last_error=? WHERE provider_event_id=?", (err, f"evt_{i}"))
    conn.commit()
    assert replay_dead.replay(conn, error="signature_invalid", dry_run=True) == 2
    assert queue.stats(conn, now=200)["pending"] == 0
    assert replay_dead.replay(conn, error="signature_invalid") == 2
    assert queue.stats(conn, now=200)["pending"] == 2
    assert queue.stats(conn, now=200)["dead_by_error"] == {"orders_api_503": 1}
