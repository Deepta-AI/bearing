#!/usr/bin/env python3
"""evals_data: what the handbook's Evals page shows, from what is on disk.

Reads evals/triggers.json and evals/<skill>/evals.json (what is defined) and
evals/scoreboard.jsonl (what was measured, one row per `make evals-weekly`
run, written by bin/eval-scoreboard.py). Nothing is estimated: a skill with
no measurement says so, and a page with no scoreboard rows says "not
measured yet" rather than showing a number.

bin/gen-guide.py imports evals() for site/src/data/handbook.json. Run alone
it prints the counts it read:

  evals_data.py [--kit <dir>] [--board <scoreboard.jsonl>]
"""

import argparse
import json
import os

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _rows(board):
    if not os.path.isfile(board):
        return []
    with open(board, encoding="utf-8") as f:
        return [json.loads(ln) for ln in f if ln.strip()]


def evals(kit=KIT, board=None):
    board = board or os.path.join(kit, "evals", "scoreboard.jsonl")
    d = os.path.join(kit, "evals")
    triggers = json.load(open(os.path.join(d, "triggers.json"), encoding="utf-8"))
    defined = {}
    for name in sorted(os.listdir(d)):
        p = os.path.join(d, name, "evals.json")
        if os.path.isfile(p):
            defined[name] = len(json.load(open(p, encoding="utf-8")).get("evals") or [])
    rows = _rows(board)

    # The newest measurement of each skill in any row: the weekly rotation
    # measures a different set each time.
    trig, arms = {}, {}
    for r in rows:
        for sk, c in ((r.get("trigger") or {}).get("skills") or {}).items():
            trig[sk] = {
                "date": r["date"],
                "loaded": c[0],
                "should": c[1],
                "false": c[2],
                "near": c[3],
            }
        for sk, m in ((r.get("skill_evals") or {}).get("skills") or {}).items():
            if m.get("arms"):
                arms[sk] = {
                    "date": m.get("date") or r["date"],
                    "cases": m.get("cases"),
                    "arms": {
                        k: round(v["pass_rate"], 4)
                        for k, v in sorted(m["arms"].items())
                    },
                    "margin": m.get("margin"),
                    "result": m.get("result", ""),
                }

    history = []
    for r in rows:
        t, h, se = (
            r.get("trigger") or {},
            r.get("harness") or {},
            r.get("skill_evals") or {},
        )
        history.append(
            {
                "date": r["date"],
                "commit": (r.get("commit") or "")[:7],
                "triggerCases": t.get("cases", 0),
                "recall": t.get("recall"),
                "falseRate": t.get("false_rate"),
                "harnessPassed": h.get("passed", 0),
                "harnessRuns": h.get("runs", 0),
                "skillsMeasured": se.get("measured", 0),
                "limited": bool(
                    t.get("limited") or h.get("limited") or se.get("limited")
                ),
            }
        )

    return {
        "triggerSkills": len(triggers),
        "triggerRequests": sum(
            len(x.get("should", [])) + len(x.get("near", [])) for x in triggers
        ),
        "skillsWithEvals": len(defined),
        "evalCases": sum(defined.values()),
        "runs": history,
        "triggerMeasured": dict(sorted(trig.items())),
        "skillsMeasured": dict(sorted(arms.items())),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--kit", default=KIT)
    ap.add_argument("--board")
    a = ap.parse_args()
    e = evals(a.kit, a.board)
    print(
        f"evals_data: {e['skillsWithEvals']} skills with evals ({e['evalCases']} cases), "
        f"{e['triggerRequests']} trigger requests over {e['triggerSkills']} skills; "
        f"{len(e['runs'])} scoreboard rows, {len(e['triggerMeasured'])} skills trigger-measured, "
        f"{len(e['skillsMeasured'])} measured with and without"
    )
    return 0 if e["skillsWithEvals"] and e["triggerRequests"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
