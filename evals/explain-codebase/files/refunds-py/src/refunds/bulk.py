"""Bulk refunds from the support desk's CSV export: order_id,amount,reason (amount in whole rupees)."""
import csv
import sys

from refunds import config, log
from refunds.store import Store

# Rows at or above this many rupees wait for a manager.
REVIEW_FROM_RUPEES = 5000

logger = log.get("refunds.bulk")


def import_rows(store: Store, rows) -> int:
    count = 0
    for row in rows:
        rupees = int(row["amount"])
        status = "awaiting_approval" if rupees >= REVIEW_FROM_RUPEES else "approved"
        store.insert_refund(row["order_id"], rupees * 100, row["reason"].strip(), status)
        count += 1
    return count


def main():
    cfg = config.load()
    store = Store(cfg.db_path)
    with open(sys.argv[1], newline="") as f:
        count = import_rows(store, csv.DictReader(f))
    logger.info("imported %d refunds", count)


if __name__ == "__main__":
    main()
