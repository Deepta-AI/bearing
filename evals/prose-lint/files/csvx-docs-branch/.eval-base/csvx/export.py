import csv


def export(src, dest, columns=None):
    """Copy the rows of src to dest, keeping only columns when given."""
    with open(src, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        fields = columns or reader.fieldnames
        rows = list(reader)
    if not rows:
        return 0
    with open(dest, "w", newline="", encoding="utf-8") as out:
        w = csv.DictWriter(out, fieldnames=fields, extrasaction="ignore")
        w.writeheader()
        w.writerows(rows)
    return len(rows)
