#!/usr/bin/env python3
"""eval-scoreboard: one row of evals/scoreboard.jsonl from a trigger-eval and
a harness-eval run, compared with the row before it.

The row holds the date, the commit measured, trigger totals (cases, errored,
recall, false-trigger rate) and per skill, the harness pass rate per scenario,
and skill_evals (from bin/skill-evals-run.py's summary.json, or null when
it did not run). The file
is tracked and read by no site: the numbers are for merge requests and the
maintainers, not the handbook.

A regression is recall down, or the false-trigger rate up, by more than
--max-drop (default 0.05), or any harness scenario's pass rate lower than in
the previous row. The row is written anyway, so the history stays honest.
Per-skill moves are listed and never fail the run: a skill has too few
requests to gate on. A skill whose with_skill pass rate fell by more than
--max-skill-drop (default 0.10) since its previous measurement in any row is a
regression too.

Usage: eval-scoreboard.py --trigger <results.json> --harness <results.json>
                          [--board evals/scoreboard.jsonl] [--max-drop R]
                          [--skill-evals <summary.json>] [--max-skill-drop R]
Prints "eval-scoreboard: N trigger cases, M harness runs checked" and what
moved; exits 2 when a results file is missing or unreadable, 1 when zero cases
were checked (nothing written) or on a regression, else 0.
"""

import argparse
import datetime
import json
import os
import subprocess
import sys

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BOARD = os.path.join(KIT, "evals", "scoreboard.jsonl")


def load(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError) as e:
        print(f"eval-scoreboard: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(2)


def commit():
    try:
        return subprocess.run(
            ["git", "-C", KIT, "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def trigger_row(data):
    results = [r for r in data.get("results", []) if r.get("status") != "error"]
    errored = len(data.get("results", [])) - len(results)
    should = [r for r in results if r["kind"] == "should"]
    near = [r for r in results if r["kind"] == "near"]
    skills = {}
    for r in results:
        s = skills.setdefault(r["skill"], [0, 0, 0, 0])
        if r["kind"] == "should":
            s[0] += r["status"] == "pass"
            s[1] += 1
        else:
            s[2] += r["status"] == "fail"
            s[3] += 1
    return {
        "cases": len(results),
        "errored": errored,
        "recall": round(sum(r["status"] == "pass" for r in should) / len(should), 4)
        if should
        else 0.0,
        "false_rate": round(sum(r["status"] == "fail" for r in near) / len(near), 4)
        if near
        else 0.0,
        "sources": data.get("sources"),
        "model": data.get("model"),
        # [should loaded, should total, near false triggers, near total]
        "skills": dict(sorted(skills.items())),
    }


def harness_row(rows):
    by = {}
    for r in rows:
        by.setdefault(r["scenario"], []).append(r["status"] == "pass")
    return {
        "runs": len(rows),
        "passed": sum(r["status"] == "pass" for r in rows),
        "scenarios": {n: round(sum(v) / len(v), 4) for n, v in sorted(by.items())},
    }


def last_row(board):
    if not os.path.isfile(board):
        return None
    with open(board) as f:
        lines = [ln for ln in f if ln.strip()]
    return json.loads(lines[-1]) if lines else None


def measured_before(board):
    """skill -> its newest skill-evals measurement in any row so far."""
    out = {}
    if os.path.isfile(board):
        with open(board) as f:
            for ln in f:
                if ln.strip():
                    se = json.loads(ln).get("skill_evals") or {}
                    for sk, m in (se.get("skills") or {}).items():
                        if m.get("arms"):
                            out[sk] = m
    return out


def skill_evals_row(summary):
    """The row's skill_evals slot from a skill-evals-run summary.json."""
    skills = summary.get("skills") or {}
    keep = {
        sk: {k: m[k] for k in ("date", "commit", "cases", "arms", "margin", "result", "closest", "model") if k in m}
        for sk, m in skills.items()
        if "error" not in m
    }
    failed = {sk: m["error"] for sk, m in skills.items() if "error" in m}
    return {"chosen": len(skills), "measured": len(keep), "failed": failed, "skills": dict(sorted(keep.items()))}


def pct(x):
    return f"{x:.0%}"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--trigger", required=True)
    ap.add_argument("--harness", required=True)
    ap.add_argument("--board", default=BOARD)
    ap.add_argument("--max-drop", type=float, default=0.05)
    ap.add_argument("--skill-evals", help="a skill-evals-run summary.json")
    ap.add_argument("--max-skill-drop", type=float, default=0.10)
    a = ap.parse_args()

    t = trigger_row(load(a.trigger))
    h = harness_row(load(a.harness))
    se = skill_evals_row(load(a.skill_evals)) if a.skill_evals else None
    print(
        f"eval-scoreboard: {t['cases']} trigger cases, {h['runs']} harness runs checked"
    )
    if t["cases"] == 0 or h["runs"] == 0:
        print(
            "eval-scoreboard: 0 cases checked in a suite; nothing written",
            file=sys.stderr,
        )
        return 1

    row = {
        "date": datetime.date.today().isoformat(),
        "commit": commit(),
        "trigger": t,
        "harness": h,
        "skill_evals": se,
    }
    prev = last_row(a.board)
    before = measured_before(a.board)
    os.makedirs(os.path.dirname(os.path.abspath(a.board)), exist_ok=True)
    with open(a.board, "a") as f:
        f.write(json.dumps(row, sort_keys=True) + "\n")

    regressions = []
    if prev is None:
        print(
            f"  recall {pct(t['recall'])}, false triggers {pct(t['false_rate'])}, "
            f"harness {h['passed']}/{h['runs']} passed; no previous row"
        )
    else:
        pt, ph = prev["trigger"], prev["harness"]
        print(
            f"  recall {pct(t['recall'])} ({(t['recall'] - pt['recall']) * 100:+.1f} points), "
            f"false triggers {pct(t['false_rate'])} ({(t['false_rate'] - pt['false_rate']) * 100:+.1f} points), "
            f"harness {h['passed']}/{h['runs']} passed; since {prev['date']} ({(prev.get('commit') or 'unknown')[:7]})"
        )
        if pt["recall"] - t["recall"] > a.max_drop:
            regressions.append(f"recall {pct(pt['recall'])} -> {pct(t['recall'])}")
        if t["false_rate"] - pt["false_rate"] > a.max_drop:
            regressions.append(
                f"false triggers {pct(pt['false_rate'])} -> {pct(t['false_rate'])}"
            )
        for n, rate in h["scenarios"].items():
            was = ph["scenarios"].get(n)
            if was is not None and rate < was:
                regressions.append(f"harness {n} {pct(was)} -> {pct(rate)}")
        for s, now in t["skills"].items():
            was = pt["skills"].get(s)
            if was and was != now:
                print(
                    f"  {s}: loaded {was[0]}/{was[1]} -> {now[0]}/{now[1]}, "
                    f"false triggers {was[2]}/{was[3]} -> {now[2]}/{now[3]}"
                )
    if se is not None:
        print(f"  skill-evals: {se['chosen']} chosen, {se['measured']} skills measured, {len(se['failed'])} failed")
        for sk, m in se["skills"].items():
            now = m["arms"]["with_skill"]["pass_rate"]
            was = before.get(sk, {}).get("arms", {}).get("with_skill", {}).get("pass_rate")
            print(f"  {sk}: with_skill {pct(now)}" + (f" (was {pct(was)})" if was is not None else " (first measurement)"))
            if was is not None and was - now > a.max_skill_drop:
                regressions.append(f"skill {sk} with_skill {pct(was)} -> {pct(now)}")
    else:
        print("  skill-evals: not run")
    if t["errored"]:
        print(f"  {t['errored']} trigger cases errored and were left out")
    for r in regressions:
        print(f"regression: {r}")
    print(
        f"eval-scoreboard: row written to {os.path.relpath(a.board, KIT)}; {len(regressions)} regressions"
    )
    return 1 if regressions else 0


if __name__ == "__main__":
    sys.exit(main())
