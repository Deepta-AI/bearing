#!/usr/bin/env python3
"""eval-audit: which expectations tell a run with the skill from one without.

Reads every graded, unblinded skill-evals run (<ws>/<skill>/iteration-N/
eval-<id>-<slug>/<arm>/run-1/grading.json, the arm being with_skill,
without_skill or with_the_alternative; a run still named arm-N is not yet
unblinded and is skipped) and counts, per expectation, how often it passed in
each arm. Each expectation lands in one class:

  discriminating    passes more often with the skill than without
  no signal         passes in every run of every arm: it measures nothing
  never passes      fails in every run of every arm: broken, contradictory or
                    asking for what no run can do
  favours no skill  passes more often without the skill than with it
  even              runs in both arms, same rate, not every time

and, separately, flagged: a grader's eval_feedback names it. Rewrite or drop
the no-signal, never-passes and flagged ones; read the favours-no-skill ones
against the skill.

Usage: eval-audit.py [--ws D ...] [--skill S] [--json F]
Prints the problem expectations and "eval-audit: N skills, M graded runs, K
expectations: ..."; exits 1 when it found no graded run.
"""

import argparse
import collections
import glob
import json
import os
import re
import sys

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = os.environ.get("BRG_SKILL_EVALS_WS") or os.path.join(
    KIT, ".scratch", "skill-evals"
)
ARMS = ("with_skill", "without_skill", "with_the_alternative")


def collect(roots, only):
    # counts[skill][case][text][arm] = [passed, runs]
    counts = collections.defaultdict(
        lambda: collections.defaultdict(
            lambda: collections.defaultdict(
                lambda: collections.defaultdict(lambda: [0, 0])
            )
        )
    )
    flags = collections.defaultdict(list)
    runs = 0
    for root in roots:
        for g in glob.glob(
            os.path.join(
                root, "*", "iteration-*", "eval-*", "*", "run-1", "grading.json"
            )
        ):
            parts = g.split(os.sep)
            skill, case_dir, arm = parts[-6], parts[-4], parts[-3]
            if arm not in ARMS or (only and skill != only):
                continue
            m = re.match(r"eval-(\d+)-", case_dir)
            case = m.group(1) if m else case_dir
            try:
                d = json.load(open(g))
            except (OSError, ValueError):
                continue
            runs += 1
            for e in d.get("expectations", []):
                c = counts[skill][case][e.get("text", "").strip()][arm]
                c[0] += bool(e.get("passed"))
                c[1] += 1
            for s in (d.get("eval_feedback") or {}).get("suggestions", []) or []:
                if s.get("assertion"):
                    flags[(skill, case, s["assertion"].strip())].append(
                        s.get("reason", "").strip()
                    )
    return counts, flags, runs


def rate(c):
    return c[0] / c[1] if c[1] else None


def classify(arms):
    w, wo = arms.get("with_skill"), arms.get("without_skill")
    seen = [c for c in arms.values() if c[1]]
    if seen and all(c[0] == c[1] for c in seen):
        return "no signal"
    if seen and all(c[0] == 0 for c in seen):
        return "never passes"
    if w and wo and w[1] and wo[1]:
        if rate(w) > rate(wo):
            return "discriminating"
        if rate(wo) > rate(w):
            return "favours no skill"
    return "even"


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument(
        "--ws",
        action="append",
        help="a skill-evals workspace (repeatable; default .scratch/skill-evals)",
    )
    ap.add_argument("--skill")
    ap.add_argument("--json")
    a = ap.parse_args()

    counts, flags, runs = collect(a.ws or [WS], a.skill)
    if not runs:
        print(
            "eval-audit: 0 graded runs found; run skill-evals-run first",
            file=sys.stderr,
        )
        return 1
    tally = collections.Counter()
    out = {}
    lines = collections.defaultdict(list)
    for skill in sorted(counts):
        out[skill] = {}
        for case in sorted(counts[skill], key=lambda x: (len(x), x)):
            out[skill][case] = []
            for text, arms in counts[skill][case].items():
                cls = classify(arms)
                tally[cls] += 1

                def show(arm):
                    c = arms.get(arm)
                    return f"{c[0]}/{c[1]}" if c and c[1] else "-"

                where = f"{skill} case {case}: {text[:110]}"
                if cls in ("no signal", "never passes", "favours no skill"):
                    lines[cls].append(
                        f"{cls}: {where} (with {show('with_skill')}, without {show('without_skill')})"
                    )
                fl = flags.get((skill, case, text))
                if fl:
                    tally["flagged"] += 1
                    lines["flagged"].append(f"flagged: {where} ({fl[0][:140]})")
                out[skill][case].append(
                    {
                        "text": text,
                        "class": cls,
                        "flagged": bool(fl),
                        **{arm: arms[arm] for arm in arms},
                    }
                )
    for cls in ("never passes", "favours no skill", "no signal", "flagged"):
        for ln in lines[cls]:
            print(ln)
    n = sum(len(t) for s in counts.values() for t in s.values())
    print(
        f"eval-audit: {len(counts)} skills, {runs} graded runs, {n} expectations: "
        f"{tally['discriminating']} discriminating, {tally['no signal']} no signal, "
        f"{tally['never passes']} never passes, {tally['favours no skill']} favours no skill, "
        f"{tally['even']} even, {tally['flagged']} flagged".replace(", 0 even", "")
    )
    if a.json:
        with open(a.json, "w") as f:
            json.dump(out, f, indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
