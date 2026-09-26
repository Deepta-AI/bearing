"""Prometheus text exposition for the worker's /metrics (port METRICS_PORT)."""

from app import queue

DEAD_LETTERS_TOTAL = {"count": 0}


def render(conn, now=None):
    s = queue.stats(conn, now)
    lines = [
        "# TYPE payhook_queue_pending gauge",
        f"payhook_queue_pending {s['pending']}",
        "# TYPE payhook_queue_oldest_pending_seconds gauge",
        f"payhook_queue_oldest_pending_seconds {s['oldest_pending_seconds']}",
        "# TYPE payhook_queue_in_progress gauge",
        f"payhook_queue_in_progress {s['in_progress']}",
        "# TYPE payhook_dead_letters_total counter",
        f"payhook_dead_letters_total {DEAD_LETTERS_TOTAL['count']}",
    ]
    return "\n".join(lines) + "\n"
