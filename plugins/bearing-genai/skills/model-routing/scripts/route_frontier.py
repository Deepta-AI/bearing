#!/usr/bin/env python3
"""route_frontier: the cheapest model or cascade that still passes the eval.

Reads one llm-eval results file per candidate model (JSON Lines, one row per
case, the schema llm-eval step 4 writes):
  {"case_id": str, "score": float 0..1, "model": str, "cost_usd": float,
   "latency_ms": number, "truncated": bool, "valid": bool|null, ...}

Usage:
  route_frontier.py --threshold <x> <results.jsonl>... [--resamples 2000]
                    [--seed 7] [--max-truncated 0.05]

Per candidate: mean score over the rows that are not truncated, the lower
bound of a percentile bootstrap 95% interval (the same block as llm-eval's
eval_stats.py), cost per 1,000 requests (mean cost_usd over every row x
1000) and p95 latency by nearest rank over every row.

Cascade, for each pair with the cheaper model first whose rows all carry
`valid` (a truncated row counts as not valid), over the case ids both files
share (a note says so when they share fewer than either file holds): a valid case keeps the small model's score, cost and latency; any
other case takes the large model's score and pays both costs and both
latencies. `valid` is only what the gateway can check at run time, so the
saving simulated here is the one production sees.

An option is eligible when its lower bound is at or above the threshold
and its truncated share is at most --max-truncated. The cheapest eligible
option wins, then the lowest p95.

Output, one line per option, then the decision:
  option <name>: n N, mean M, lower L, $C per 1k, p95 P ms, truncated T[, escalated E%][, ineligible (...)]
  route-frontier: K options (J cascades), N rows, chose <name> (lower L >= X, $C per 1k)
Exit 0 on a choice; 1 with "none meets threshold X"; 2 when nothing was
checked (no files, zero rows, zero scored rows) or a file cannot be trusted
(more than one model, a row without a price, a malformed row).
"""

import argparse
import json
import math
import random
import sys


def die(msg):
    print(f"route-frontier: {msg}", file=sys.stderr)
    sys.exit(2)


def is_num(x):
    return isinstance(x, (int, float)) and not isinstance(x, bool)


def load(path):
    """Rows of one candidate in file order. Exits 2 on anything untrustworthy."""
    try:
        lines = open(path, encoding="utf-8").read().splitlines()
    except OSError as e:
        die(f"cannot read {path}: {e.strerror}")
    rows, seen, models = [], set(), []
    for n, raw in enumerate(lines, 1):
        if not raw.strip():
            continue
        try:
            r = json.loads(raw)
        except ValueError:
            die(f"{path} line {n}: not JSON")
        if (
            not isinstance(r, dict)
            or not isinstance(r.get("case_id"), str)
            or not r["case_id"]
        ):
            die(f"{path} line {n}: no case_id")
        cid = r["case_id"]
        if cid in seen:
            die(f"{path} line {n}: duplicate case_id {cid}")
        seen.add(cid)
        m = r.get("model")
        if not isinstance(m, str) or not m:
            die(f"{path} line {n}: no model")
        if m not in models:
            models.append(m)
        r["truncated"] = r.get("truncated") is True
        s = r.get("score")
        if not r["truncated"] and (not is_num(s) or not 0 <= s <= 1):
            die(f"{path} line {n}: score must be a number from 0 to 1 ({cid})")
        if not is_num(r.get("latency_ms")) or r["latency_ms"] < 0:
            die(f"{path} line {n}: no latency_ms ({cid})")
        v = r.get("valid")
        if v is not None and not isinstance(v, bool):
            die(f"{path} line {n}: valid must be true, false or null ({cid})")
        rows.append(r)
    if not rows:
        die(f"{path}: 0 rows: nothing checked")
    if len(models) > 1:
        die(
            f"{path} holds models {', '.join(models)}: a fallback ran during the eval; re-run it"
        )
    for r in rows:
        c = r.get("cost_usd")
        if not is_num(c) or c < 0:
            die(
                f"no price for {models[0]} ({path}, case {r['case_id']}): add its price row with source and date, or leave it out"
            )
    return models[0], rows


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


def money(x):
    return f"{x:.2f}" if x >= 0.095 else f"{x:.2g}"


def num(x):
    return f"{x:g}"


def p95(latencies):
    s = sorted(latencies)
    return s[max(0, math.ceil(0.95 * len(s)) - 1)]


def option(name, rows, a, escalated=None):
    """rows: dicts with score, truncated, cost_usd, latency_ms."""
    kept = [r["score"] for r in rows if not r["truncated"]]
    trunc = len(rows) - len(kept)
    if not kept:
        die(f"{name}: 0 rows scored ({trunc} truncated): nothing checked")
    lo, _ = bootstrap(kept, a.resamples, a.seed)
    o = {
        "name": name,
        "n": len(kept),
        "mean": sum(kept) / len(kept),
        "lower": lo,
        "cost": sum(r["cost_usd"] for r in rows) / len(rows) * 1000,
        "p95": p95([r["latency_ms"] for r in rows]),
        "trunc": trunc,
        "share": trunc / len(rows),
        "escalated": escalated,
    }
    line = (
        f"option {name}: n {o['n']}, mean {f3(o['mean'])}, lower {f3(lo)}, "
        f"${money(o['cost'])} per 1k, p95 {num(round(o['p95']))} ms, truncated {trunc}"
    )
    if escalated is not None:
        line += f", escalated {escalated * 100:.1f}%"
    o["ok_trunc"] = o["share"] <= a.max_truncated + 1e-12
    if not o["ok_trunc"]:
        line += f", ineligible (truncated {f3(o['share'])} > {num(a.max_truncated)})"
    o["line"] = line
    return o


def cascade(small, large, a, notes):
    """small, large: (model, rows). Returns an option or a reason it is not
    simulated; a cascade over fewer cases than either file adds a note."""
    (sm, srows), (lm, lrows) = small, large
    if not any(isinstance(r.get("valid"), bool) for r in srows):
        return None, f"cascade {sm}->{lm}: not simulated (cheaper model has no valid)"
    without = sum(
        1 for r in srows if not r["truncated"] and not isinstance(r.get("valid"), bool)
    )
    if without:
        return None, f"cascade {sm}->{lm}: not simulated ({without} rows without valid)"
    big = {r["case_id"]: r for r in lrows}
    shared = [r for r in srows if r["case_id"] in big]
    if not shared:
        return None, f"cascade {sm}->{lm}: not simulated (0 shared cases)"
    if len(shared) < max(len(srows), len(lrows)):
        notes.append(
            f"cascade {sm}->{lm}: note: simulated on {len(shared)} shared cases "
            f"({sm} has {len(srows)}, {lm} has {len(lrows)})"
        )
    rows, up = [], 0
    for s in shared:
        if not s["truncated"] and s["valid"] is True:
            rows.append(s)
            continue
        b = big[s["case_id"]]
        up += 1
        rows.append(
            {
                "score": b.get("score"),
                "truncated": b["truncated"],
                "cost_usd": s["cost_usd"] + b["cost_usd"],
                "latency_ms": s["latency_ms"] + b["latency_ms"],
            }
        )
    return option(f"cascade {sm}->{lm}", rows, a, escalated=up / len(shared)), None


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--threshold", type=float, required=True)
    ap.add_argument("files", nargs="*")
    ap.add_argument("--resamples", type=int, default=2000)
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("--max-truncated", type=float, default=0.05)
    a = ap.parse_args()
    if a.resamples < 1:
        die("--resamples must be at least 1")
    if not a.files:
        die("0 files: nothing checked")
    cands, where = [], {}
    for f in a.files:
        m, rows = load(f)
        if m in where:
            die(f"{m} is in both {where[m]} and {f}: one file per candidate")
        where[m] = f
        cands.append((m, rows))
    total = sum(len(r) for _, r in cands)
    opts = [option(m, rows, a) for m, rows in cands]
    cost = {o["name"]: o["cost"] for o in opts}
    notes, cascades = [], []
    has_valid = any(
        any(isinstance(r.get("valid"), bool) for r in rows) for _, rows in cands
    )
    if len(cands) > 1 and not has_valid:
        notes.append(
            "cascade: not simulated (no deterministic validity in the results)"
        )
    elif len(cands) > 1:
        for small in cands:
            for large in cands:
                if large is small or cost[small[0]] >= cost[large[0]]:
                    continue
                o, why = cascade(small, large, a, notes)
                if o:
                    cascades.append(o)
                else:
                    notes.append(why)
    opts += cascades
    for o in opts:
        print(o["line"])
    for line in notes:
        print(line)
    ok = [o for o in opts if o["ok_trunc"] and o["lower"] >= a.threshold - 1e-9]
    head = (
        f"route-frontier: {len(opts)} options ({len(cascades)} cascades), {total} rows"
    )
    if not ok:
        print(f"{head}, none meets threshold {num(a.threshold)}")
        return 1
    best = min(ok, key=lambda o: (round(o["cost"], 9), o["p95"], o["name"]))
    print(
        f"{head}, chose {best['name']} (lower {f3(best['lower'])} >= {num(a.threshold)}, "
        f"${money(best['cost'])} per 1k)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
