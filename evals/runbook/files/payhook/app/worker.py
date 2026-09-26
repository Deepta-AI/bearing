"""Worker: claim a batch, apply each event through the Orders API, sleep.

One batch of BATCH_SIZE every POLL_INTERVAL_SECONDS per replica. Events are
applied one at a time; a slow Orders API (timeout ORDERS_API_TIMEOUT_SECONDS)
slows the whole batch.
"""

import json
import time
import urllib.request

from app import config, db, metrics, queue


class OrdersApiError(Exception):
    pass


def apply_event(kind, payload):
    body = json.dumps({"kind": kind, "payload": json.loads(payload)}).encode()
    req = urllib.request.Request(
        f"{config.ORDERS_API_URL}/internal/payment-events",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=config.ORDERS_API_TIMEOUT_SECONDS) as resp:
            if resp.status >= 300:
                raise OrdersApiError(f"orders_api_{resp.status}")
    except OSError as e:
        raise OrdersApiError("orders_api_unreachable") from e


def run_once(conn, apply=apply_event, now=None):
    handled = 0
    for event_id, kind, payload, attempts in queue.claim_batch(conn, now=now):
        try:
            apply(kind, payload)
            queue.mark_done(conn, event_id)
        except OrdersApiError as e:
            if queue.mark_failed(conn, event_id, attempts, str(e)) == "dead":
                metrics.DEAD_LETTERS_TOTAL["count"] += 1
        handled += 1
    return handled


def main():
    conn = db.connect()
    while True:
        run_once(conn)
        time.sleep(config.POLL_INTERVAL_SECONDS)


if __name__ == "__main__":
    main()
