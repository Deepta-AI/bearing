import argparse

from csvx.export import export

NO_MATCH = "0 rows matched {{EMDASH}} nothing written"


def main(argv=None):
    p = argparse.ArgumentParser(prog="csvx")
    p.add_argument("src", help="input CSV")
    p.add_argument("dest", help="output CSV")
    p.add_argument("--columns", default=None, help="comma-separated columns to keep")
    a = p.parse_args(argv)
    columns = a.columns.split(",") if a.columns else None
    n = export(a.src, a.dest, columns=columns)
    if n == 0:
        print(NO_MATCH)
    else:
        print(f"{n} rows written to {a.dest}")
    return 0
