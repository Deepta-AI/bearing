#!/usr/bin/env python3
"""split_check: prove a train and test split cannot leak, so the score in
tabular-ml's report comes from data the model could not have seen.

Reads two CSV files with headers (and an optional validation file) and
checks, for the columns named:
  --time COL   every train row is strictly earlier than every test row
               (and validation sits between them when given). Values are
               compared as numbers when every value parses as one, else
               as text, which orders ISO 8601 dates correctly.
  --group COL  no group (user, customer, patient, device) appears in more
               than one split.
  --target COL the target is present in every row and both files have at
               least two target values (a one-class split scores nothing).
At least one of --time or --group is required: a random row split of
event data is the leak this check exists for.

Usage: split_check.py --train train.csv --test test.csv [--valid valid.csv]
                      [--time COL] [--group COL] [--target COL]
Prints one line per problem, then
  ml-split: train N, valid V, test M rows; time <ok|LEAK|not checked>;
    groups overlapping K; target <ok|problem|not checked>; P problems
and exits 1 when any file has zero rows, a named column is missing, or
any problem is found.
"""

import argparse
import csv
import sys


def load(path):
    if not path:
        return None
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def ordered(values):
    try:
        return [float(v) for v in values]
    except ValueError:
        return list(values)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--train", required=True)
    ap.add_argument("--test", required=True)
    ap.add_argument("--valid")
    ap.add_argument("--time")
    ap.add_argument("--group")
    ap.add_argument("--target")
    args = ap.parse_args()
    if not args.time and not args.group:
        print(
            "ml-split: name --time or --group (or both); a random row split is not checked"
        )
        return 2

    splits = [
        ("train", load(args.train)),
        ("valid", load(args.valid)),
        ("test", load(args.test)),
    ]
    splits = [(n, rows) for n, rows in splits if rows is not None]
    problems = 0
    for name, rows in splits:
        if not rows:
            print(f"empty split: {name}")
            problems += 1
        for col in filter(None, (args.time, args.group, args.target)):
            if rows and col not in rows[0]:
                print(f"missing column {col!r} in {name}")
                problems += 1
    counts = {n: len(r) for n, r in splits}
    if problems:
        print(
            f"ml-split: train {counts.get('train', 0)}, valid {counts.get('valid', 0)}, test {counts.get('test', 0)} rows; {problems} problems"
        )
        return 1

    time_state = "not checked"
    if args.time:
        time_state = "ok"
        for (a, ra), (b, rb) in zip(splits, splits[1:]):
            vals = ordered([r[args.time] for r in ra] + [r[args.time] for r in rb])
            va, vb = vals[: len(ra)], vals[len(ra) :]
            if max(va) >= min(vb):
                print(f"time leak: {a} ends at {max(va)} but {b} starts at {min(vb)}")
                time_state = "LEAK"
                problems += 1

    overlap = 0
    if args.group:
        seen = {}
        for name, rows in splits:
            for g in {r[args.group] for r in rows}:
                seen.setdefault(g, set()).add(name)
        shared = sorted(g for g, where in seen.items() if len(where) > 1)
        overlap = len(shared)
        if shared:
            print(
                f"group leak: {overlap} {args.group} values in more than one split, e.g. {', '.join(shared[:5])}"
            )
            problems += 1

    target_state = "not checked"
    if args.target:
        target_state = "ok"
        for name, rows in splits:
            vals = [r[args.target] for r in rows]
            if any(v.strip() == "" for v in vals) or len(set(vals)) < 2:
                print(
                    f"target problem in {name}: blank values or fewer than two classes"
                )
                target_state = "problem"
                problems += 1

    print(
        f"ml-split: train {counts.get('train', 0)}, valid {counts.get('valid', 0)}, test {counts.get('test', 0)} rows; "
        f"time {time_state}; groups overlapping {overlap}; target {target_state}; {problems} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
