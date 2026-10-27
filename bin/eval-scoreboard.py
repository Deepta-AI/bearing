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
    allr = data.get("results", [])
    results = [r for r in allr if r.get("status") in ("pass", "fail")]
    errored = sum(r.get("status") == "error" for r in allr)
    not_run = sum(r.get("status") == "not run" for r in allr)
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
        "not_run": not_run,
        "limited": bool(data.get("limited")),
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
    ran = [r for r in rows if r.get("status") != "not run"]
    by = {}
    for r in ran:
        by.setdefault(r["scenario"], []).append(r["status"] == "pass")
    return {
        "runs": len(ran),
        "not_run": len(rows) - len(ran),
        "limited": len(ran) < len(rows),
        "passed": sum(r["status"] == "pass" for r in ran),
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
    failed = {sk: m["error"] for sk, m in skills.items() if "error" in m and not m.get("limited")}
    limited = sorted(sk for sk, m in skills.items() if m.get("limited"))
    return {"chosen": len(skills), "measured": len(keep), "failed": failed, "limited": limited,
            "skills": dict(sorted(keep.items()))}


def triggers_before(board):
    """skill -> its newest trigger counts in any row so far; with the weekly
    rotation each row measures a different set of skills."""
    out = {}
    if os.path.isfile(board):
        with open(board) as f:
            for ln in f:
                if ln.strip():
                    for sk, v in ((json.loads(ln).get("trigger") or {}).get("skills") or {}).items():
                        out[sk] = v
    return out


def rates(counts):
    """(recall, false rate) over [should loaded, should total, near false, near total] lists."""
    sh = sum(c[1] for c in counts)
    nr = sum(c[3] for c in counts)
    return (sum(c[0] for c in counts) / sh if sh else None,
            sum(c[2] for c in counts) / nr if nr else None)


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
    if t["cases"] == 0 and h["runs"] == 0 and not (se and se["measured"]):
        print("eval-scoreboard: 0 cases checked in every suite; nothing written", file=sys.stderr)
        return 1
    for name, n, lim in (("trigger", t["cases"], t["limited"]), ("harness", h["runs"], h["limited"])):
        if n == 0 and not lim:
            print(f"eval-scoreboard: 0 {name} cases checked and no usage limit to explain it; nothing written",
                  file=sys.stderr)
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
    trig_before = triggers_before(a.board)
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
        ph = prev.get("harness") or {}
        # Recall and false triggers over the skills measured now that were
        # measured before, each against its own last measurement.
        common = [sk for sk in t["skills"] if sk in trig_before]
        r_now, f_now = rates([t["skills"][sk] for sk in common])
        r_was, f_was = rates([trig_before[sk] for sk in common])
        if r_now is not None and r_was is not None:
            print(
                f"  recall {pct(r_now)} ({(r_now - r_was) * 100:+.1f} points), false triggers "
                f"{pct(f_now or 0)} ({((f_now or 0) - (f_was or 0)) * 100:+.1f} points) over {len(common)} skills "
                f"measured before; harness {h['passed']}/{h['runs']} passed; since {prev['date']} "
                f"({(prev.get('commit') or 'unknown')[:7]})"
            )
            if r_was - r_now > a.max_drop:
                regressions.append(f"recall {pct(r_was)} -> {pct(r_now)} over {len(common)} skills")
            if (f_now or 0) - (f_was or 0) > a.max_drop:
                regressions.append(f"false triggers {pct(f_was or 0)} -> {pct(f_now or 0)} over {len(common)} skills")
        else:
            print(f"  recall {pct(t['recall'])}, false triggers {pct(t['false_rate'])}: no skill measured "
                  f"before, nothing compared; harness {h['passed']}/{h['runs']} passed")
        for n, rate in h["scenarios"].items():
            was = (ph.get("scenarios") or {}).get(n)
            if was is not None and rate < was:
                regressions.append(f"harness {n} {pct(was)} -> {pct(rate)}")
        for s, now in t["skills"].items():
            was = trig_before.get(s)
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
    limits = []
    if t["limited"]:
        limits.append(f"trigger ({t['not_run']} cases not run)")
    if h["limited"]:
        limits.append(f"harness ({h['not_run']} scenarios not run)")
    if se is not None and se.get("limited"):
        limits.append(f"skill-evals ({len(se['limited'])} skills not run)")
    if limits:
        print(f"  stopped at the usage limit: {', '.join(limits)}; left out, not counted as failures")
    for r in regressions:
        print(f"regression: {r}")
    print(
        f"eval-scoreboard: row written to {os.path.relpath(a.board, KIT)}; {len(regressions)} regressions"
    )
    return 1 if regressions else 0


if __name__ == "__main__":
    sys.exit(main())
