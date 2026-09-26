from app import db, queue, worker


def fresh():
    return db.connect("sqlite://")


def test_claim_then_done():
    conn = fresh()
    queue.enqueue(conn, "evt_1", "payment.succeeded", "{}", now=100)
    rows = queue.claim_batch(conn, now=101)
    assert [r[0] for r in rows] == [1]
    assert queue.claim_batch(conn, now=102) == []
    queue.mark_done(conn, 1)
    assert queue.stats(conn, now=103)["pending"] == 0


def test_expired_lease_is_claimed_again():
    conn = fresh()
    queue.enqueue(conn, "evt_1", "payment.succeeded", "{}", now=100)
    queue.claim_batch(conn, now=101)
    assert queue.claim_batch(conn, now=101 + 299) == []
    assert len(queue.claim_batch(conn, now=101 + 301)) == 1


def test_dead_after_five_attempts():
    conn = fresh()
    queue.enqueue(conn, "evt_1", "payment.succeeded", "{}", now=100)

    def failing(kind, payload):
        raise worker.OrdersApiError("orders_api_503")

    for i in range(5):
        worker.run_once(conn, apply=failing, now=200 + i)
    s = queue.stats(conn, now=300)
    assert s["dead_by_error"] == {"orders_api_503": 1}
    assert s["pending"] == 0


def test_oldest_pending_age():
    conn = fresh()
    queue.enqueue(conn, "evt_1", "payment.succeeded", "{}", now=100)
    queue.enqueue(conn, "evt_2", "payment.succeeded", "{}", now=400)
    assert queue.stats(conn, now=700)["oldest_pending_seconds"] == 600.0
