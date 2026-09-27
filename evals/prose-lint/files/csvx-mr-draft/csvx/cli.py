import argparse

from csvx.export import RATINGS, export

NO_MATCH = "0 rows matched {{EMDASH}} nothing written"


def main(argv=None):
    p = argparse.ArgumentParser(prog="csvx")
    p.add_argument("src", help="input CSV with a rating column")
    p.add_argument("dest", help="output CSV")
    p.add_argument("--min-rating", choices=RATINGS, default="poor")
    p.add_argument("--batch-size", type=int, default=500)
    p.add_argument("--columns", default=None, help="comma-separated columns to keep")
    a = p.parse_args(argv)
    columns = a.columns.split(",") if a.columns else None
    n = export(a.src, a.dest, min_rating=a.min_rating, batch_size=a.batch_size, columns=columns)
    if n == 0:
        print(NO_MATCH)
    else:
        print(f"{n} rows written to {a.dest}")
    return 0
