import csv

RATINGS = ("poor", "fair", "good", "excellent")


def export(src, dest, min_rating="poor", batch_size=500, columns=None):
    """Copy rows rated min_rating or better from src to dest, flushing every batch_size rows."""
    floor = RATINGS.index(min_rating)
    with open(src, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fields = columns or reader.fieldnames
        rows = list(reader)
    kept = [r for r in rows if RATINGS.index(r["rating"]) >= floor]
    if not kept:
        return 0
    # "w" truncates: a rerun starts over from the first row.
    with open(dest, "w", newline="", encoding="utf-8") as out:
        w = csv.DictWriter(out, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        for i in range(0, len(kept), batch_size):
            w.writerows(kept[i : i + batch_size])
            out.flush()
    return len(kept)
