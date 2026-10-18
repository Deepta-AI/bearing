#!/usr/bin/env python3
"""eval_stats: intervals, paired comparison and judge calibration for llm-eval.

Reads results rows (JSON Lines), one per case, as every llm-eval harness
writes them:
  {"case_id": str, "score": float 0..1, "model": str, "usage": {...},
   "cost_usd": float|null, "latency_ms": int, "truncated": bool,
   "valid": bool|null, "label": str|null}
A truncated row (max_tokens hit) is excluded from every number and counted.

Usage:
  eval_stats.py summary <results.jsonl> [--resamples 2000] [--seed 7]
    eval-stats: N cases (T truncated, excluded), mean M, 95% CI [L, U]
  eval_stats.py compare <base.jsonl> <new.jsonl> [--resamples 2000] [--seed 7]
    eval-compare: S shared cases (base B, new W), delta +D, 95% CI [+L, +U]: better|worse|no difference
    Pairs rows by case_id where neither side is truncated; better when L > 0,
    worse when U < 0 (exit 1).
  eval_stats.py agree <people.jsonl> <judge.jsonl> [--min-items 30] [--min-kappa 0.6]
    eval-agree: S shared items, agreement A, kappa K: calibrated|uncalibrated
    Pairs `label` by case_id; calibrated needs S >= --min-items and
    kappa >= --min-kappa, else exit 1.
Every subcommand exits 2 with "nothing checked" when it has zero cases or
zero shared ids, and exits 2 on a malformed row or a duplicate case_id.
"""

import argparse
import json
import random
import sys


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(2)


def load(path, need_score=True):
    """Rows by case_id, in file order. Exits 2 on a malformed row."""
    rows = {}
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError as e:
        die(f"eval-stats: cannot read {path}: {e.strerror}")
    for n, raw in enumerate(lines, 1):
        if not raw.strip():
            continue
        try:
            r = json.loads(raw)
        except ValueError:
            die(f"eval-stats: {path} line {n}: not JSON")
        if (
            not isinstance(r, dict)
            or not isinstance(r.get("case_id"), str)
            or not r["case_id"]
        ):
            die(f"eval-stats: {path} line {n}: no case_id")
        cid = r["case_id"]
        if cid in rows:
            die(f"eval-stats: {path} line {n}: duplicate case_id {cid}")
        r["truncated"] = r.get("truncated") is True
        s = r.get("score")
        if need_score and not r["truncated"]:
            if (
                isinstance(s, bool)
                or not isinstance(s, (int, float))
                or not 0 <= s <= 1
            ):
                die(
                    f"eval-stats: {path} line {n}: score must be a number from 0 to 1 ({cid})"
                )
        rows[cid] = r
    return rows


# bootstrap: begin
def bootstrap(values, resamples, seed):
    """Percentile bootstrap 95% interval of the mean over case indices."""
    rng = random.Random(seed)
    n = len(values)
    means = sorted(
        sum(values[rng.randrange(n)] for _ in range(n)) / n for _ in range(resamples)
    )
    lo = means[int(0.025 * resamples)]
    hi = means[min(resamples - 1, int(0.975 * resamples))]
    return lo, hi


# bootstrap: end


def f3(x):
    return f"{x + 0.0:.3f}"


def s3(x):
    x = round(x, 3) + 0.0
    return f"{x:+.3f}"


def summary(a):
    rows = load(a.results)
    kept = [r["score"] for r in rows.values() if not r["truncated"]]
    trunc = len(rows) - len(kept)
    head = f"eval-stats: {len(kept)} cases ({trunc} truncated, excluded)"
    if not kept:
        die(f"{head}: nothing checked")
    lo, hi = bootstrap(kept, a.resamples, a.seed)
    print(f"{head}, mean {f3(sum(kept) / len(kept))}, 95% CI [{f3(lo)}, {f3(hi)}]")
    return 0


def compare(a):
    base, new = load(a.base), load(a.new)
    ids = [
        c
        for c in base
        if c in new and not base[c]["truncated"] and not new[c]["truncated"]
    ]
    if not ids:
        die(
            f"eval-compare: 0 shared cases (base {len(base)} rows, new {len(new)} rows): nothing checked"
        )
    b = [base[c]["score"] for c in ids]
    w = [new[c]["score"] for c in ids]
    deltas = [y - x for x, y in zip(b, w)]
    lo, hi = bootstrap(deltas, a.resamples, a.seed)
    lo, hi = round(lo, 9), round(hi, 9)
    verdict = "better" if lo > 0 else "worse" if hi < 0 else "no difference"
    n = len(ids)
    print(
        f"eval-compare: {n} shared cases (base {f3(sum(b) / n)}, new {f3(sum(w) / n)}), "
        f"delta {s3(sum(deltas) / n)}, 95% CI [{s3(lo)}, {s3(hi)}]: {verdict}"
    )
    return 1 if verdict == "worse" else 0


def labels(path):
    out = {}
    for c, r in load(path, need_score=False).items():
        lab = r.get("label")
        if not r["truncated"] and isinstance(lab, str) and lab.strip():
            out[c] = lab.strip()
    return out


def agree(a):
    people, judge = labels(a.people), labels(a.judge)
    ids = [c for c in people if c in judge]
    if not ids:
        die("eval-agree: 0 shared items with a label on both sides: nothing checked")
    n = len(ids)
    po = sum(1 for c in ids if people[c] == judge[c]) / n
    cats = {people[c] for c in ids} | {judge[c] for c in ids}
    pe = sum(
        (sum(1 for c in ids if people[c] == k) / n)
        * (sum(1 for c in ids if judge[c] == k) / n)
        for k in cats
    )
    kappa = 1.0 if pe == 1 else (po - pe) / (1 - pe)
    ok = n >= a.min_items and kappa >= a.min_kappa - 1e-9
    print(
        f"eval-agree: {n} shared items, agreement {f3(po)}, kappa {kappa + 0.0:.2f}: "
        f"{'calibrated' if ok else 'uncalibrated'}"
    )
    if n < a.min_items:
        print(
            f"eval-agree: needs at least {a.min_items} person-labelled items shared with the judge"
        )
    if not ok:
        return 1
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("summary")
    p.add_argument("results")
    q = sub.add_parser("compare")
    q.add_argument("base")
    q.add_argument("new")
    for x in (p, q):
        x.add_argument("--resamples", type=int, default=2000)
        x.add_argument("--seed", type=int, default=7)
    g = sub.add_parser("agree")
    g.add_argument("people")
    g.add_argument("judge")
    g.add_argument("--min-items", type=int, default=30)
    g.add_argument("--min-kappa", type=float, default=0.6)
    a = ap.parse_args()
    if getattr(a, "resamples", 1) < 1:
        die("eval-stats: --resamples must be at least 1")
    return {"summary": summary, "compare": compare, "agree": agree}[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
