"""Order-volume alert: pages on-call when hourly orders leave the normal range."""

import csv

LOW = 150    # orders per hour
HIGH = 2000  # orders per hour


def load(path):
    with open(path, newline="") as fh:
        return [(r["hour"], int(r["orders"])) for r in csv.DictReader(fh)]


def check(hour, orders):
    """Return an alert message for one hour, or None."""
    if orders < LOW:
        return f"{hour}: orders {orders} below {LOW}"
    if orders > HIGH:
        return f"{hour}: orders {orders} above {HIGH}"
    return None


def run(path):
    alerts = []
    for hour, orders in load(path):
        msg = check(hour, orders)
        if msg:
            alerts.append(msg)
    return alerts


if __name__ == "__main__":
    import sys

    for line in run(sys.argv[1] if len(sys.argv) > 1 else "data/orders_hourly.csv"):
        print("PAGE", line)
