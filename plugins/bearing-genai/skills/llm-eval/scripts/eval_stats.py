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
    worse when U < 0 (exit 1). First prints "eval-compare: warning: <file>
    holds models a, b: ..." for a run whose rows name more than one model.
  eval_stats.py agree <people.jsonl> <judge.jsonl> [--min-items 30] [--min-kappa 0.6]
    eval-agree: S shared items, agreement A, kappa K: calibrated|uncalibrated
    Pairs `label` by case_id; calibrated needs S >= --min-items and
    kappa >= --min-kappa, else exit 1.
  eval_stats.py vendor <dest>
    eval-stats vendor: wrote <dest> from bearing-genai <version>, sha256 <h>
    Copies this script into a repository (evals/tools/eval_stats.py) so CI
    runs the same statistics without the plugin. Two header lines after
    the shebang name the source and version and the sha256 of the body.
  eval_stats.py parity <vendored.py>
    eval-stats parity: 1 file checked, same as bearing-genai <version>
    Exit 1 when the copy's body differs from its header's sha256 (edited)
    or from this script (out of date); exit 2 when the file has no header.
Every subcommand exits 2 with "nothing checked" when it has zero cases or
zero shared ids, and exits 2 on a malformed row or a duplicate case_id.
"""

import argparse
import hashlib
import json
import os
import random
import sys

VENDOR_FROM = "# vendored-from: "
VENDOR_SHA = "# vendored-sha256: "
SOURCE = "skills/llm-eval/scripts/eval_stats.py"


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


def models_in(rows):
    out = []
    for r in rows.values():
        m = r.get("model")
        if isinstance(m, str) and m and m not in out:
            out.append(m)
    return out


def compare(a):
    base, new = load(a.base), load(a.new)
    for path, rows in ((a.base, base), (a.new, new)):
        ms = models_in(rows)
        if len(ms) > 1:
            print(
                f"eval-compare: warning: {path} holds models {', '.join(ms)}: "
                "a fallback ran during that run, so it measures a mix of models"
            )
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


def body_of(text):
    """The script without its vendored header lines."""
    return "".join(
        ln
        for ln in text.splitlines(keepends=True)
        if not ln.startswith((VENDOR_FROM, VENDOR_SHA))
    )


def sha(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def own_text():
    return open(os.path.abspath(__file__), encoding="utf-8").read()


def vendor(a):
    here = os.path.dirname(os.path.abspath(__file__))
    pj = os.path.join(here, "..", "..", "..", ".claude-plugin", "plugin.json")
    try:
        version = json.load(open(pj, encoding="utf-8"))["version"]
    except (OSError, ValueError, KeyError):
        die("eval-stats vendor: 0 files written, nothing checked (no plugin.json "
            "beside this script; run the bearing-genai plugin's copy)")
    body = body_of(own_text())
    h = sha(body)
    first, rest = body.split("\n", 1)
    out = (
        f"{first}\n{VENDOR_FROM}bearing-genai {version} {SOURCE}\n"
        f"{VENDOR_SHA}{h} (never edit; re-copy with `eval_stats.py vendor`)\n{rest}"
    )
    d = os.path.dirname(a.dest)
    if d:
        os.makedirs(d, exist_ok=True)
    with open(a.dest, "w", encoding="utf-8") as f:
        f.write(out)
    os.chmod(a.dest, 0o755)
    print(f"eval-stats vendor: wrote {a.dest} from bearing-genai {version}, sha256 {h[:12]}")
    return 0


def parity(a):
    try:
        text = open(a.vendored, encoding="utf-8").read()
    except OSError as e:
        die(f"eval-stats parity: 0 files checked, nothing checked (cannot read {a.vendored}: {e.strerror})")
    origin = declared = None
    for ln in text.splitlines():
        if ln.startswith(VENDOR_FROM):
            origin = ln[len(VENDOR_FROM):].split(" " + SOURCE)[0].strip()
        elif ln.startswith(VENDOR_SHA):
            declared = ln[len(VENDOR_SHA):].split()[0] if ln[len(VENDOR_SHA):].split() else ""
    if not origin or not declared:
        die(f"eval-stats parity: 0 files checked, nothing checked ({a.vendored} has no vendored-from header)")
    got = sha(body_of(text))
    mine = sha(body_of(own_text()))
    if got == declared == mine:
        print(f"eval-stats parity: 1 file checked, same as {origin} (sha256 {got[:12]})")
        return 0
    why = "edited after it was copied" if got != declared else "out of date with this script"
    print(
        f"eval-stats parity: 1 file checked, differs: {a.vendored} is {why} "
        f"(body {got[:12]}, header {declared[:12]}, this script {mine[:12]}); "
        "re-copy it with `eval_stats.py vendor` from bearing-genai"
    )
    return 1


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
    v = sub.add_parser("vendor")
    v.add_argument("dest")
    y = sub.add_parser("parity")
    y.add_argument("vendored")
    a = ap.parse_args()
    if getattr(a, "resamples", 1) < 1:
        die("eval-stats: --resamples must be at least 1")
    return {
        "summary": summary,
        "compare": compare,
        "agree": agree,
        "vendor": vendor,
        "parity": parity,
    }[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
