"""CSV export of a month's invoices for finance."""

import csv
import io


def export_month(rows):
    # FIXME: builds the whole month in memory; the March export (180k rows) was OOM-killed
    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(["id", "customer_id", "date", "total"])
    for r in list(rows):
        w.writerow([r["id"], r["customer_id"], r["date"], r["total"]])
    return buf.getvalue()
