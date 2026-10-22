#!/usr/bin/env python3
"""skill-tune: propose an edit to one skill, measure it, keep it only if it wins.

The loop Harness2 (Google Research, Oct 2026) runs on a harness, here on one
Bearing skill: propose, probe, keep.

  propose  a `claude -p` session in Claude Code's Bash sandbox edits a copy of
           the skill, given its SKILL.md, its references and the expectations
           its last measurement failed, and writes why to rationale.md
  probe    the lints a skill must pass (lint-skills, lint-skill-size,
           lint-tools, no em dashes), then bin/skill-evals-run.py measures the
           copy and the skill as it is, side by side, --repeat times each
  keep     the edit stays only when the copy's with_skill pass rate beats the
           skill as it is by --min-gain (default 0.10) and its margin over no
           skill does not shrink; it is written as candidate.patch with a
           report.md, for the maintainer to read and `git apply`

Nothing in this repository changes: both copies come from `git archive HEAD`
into the run folder. The skill to tune is --skill, else the weakest measured
skill on evals/scoreboard.jsonl (lowest with_skill pass rate). --list ranks
them and stops.

Usage: skill-tune.py [--skill S] [--board F] [--out D] [--repeat N]
                     [--min-gain R] [--model M] [--list]
Exits 0 when the edit is kept, 3 when it is rejected (no edit, lint failed or
no gain), 1 on an error or when the board has no measured skill. Uses the
logged-in claude CLI (subscription), never an API key.

  BRG_SKILL_TUNE_MEASURE  the measuring command, given the kit copy first
                          (default: python3 <copy>/bin/skill-evals-run.py)
  BRG_SKILL_TUNE_LINT     the lint command run in the candidate copy
                          (default: make lint-skills lint-skill-size lint-tools)
"""

import argparse
import concurrent.futures
import datetime
import glob
import json
import os
import shlex
import shutil
import subprocess
import sys

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(KIT, "bin"))
import kit_paths  # noqa: E402

CLAUDE = os.environ.get("BRG_CLAUDE", "claude")
BOARD = os.path.join(KIT, "evals", "scoreboard.jsonl")
WS = os.path.abspath(
    os.environ.get("BRG_SKILL_EVALS_WS") or os.path.join(
    KIT, ".scratch", "skill-evals"
)
)
EM_DASH = chr(0x2014)  # spelled as a code point so no em dash sits in the source


def run_driver():
    """The sandbox settings and Claude flags the skill-evals driver uses."""
    import importlib.util

    spec = importlib.util.spec_from_file_location(
        "ser", os.path.join(KIT, "bin", "skill-evals-run.py")
    )
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def measured(board):
    out = {}
    if os.path.isfile(board):
        with open(board) as f:
            for line in f:
                if line.strip():
                    for s, m in (
                        (json.loads(line).get("skill_evals") or {}).get("skills") or {}
                    ).items():
                        if m.get("arms"):
                            out[s] = m
    return out


def rate(m, arm="with_skill"):
    return (m.get("arms", {}).get(arm) or {}).get("pass_rate", 0.0)


def rank(board):
    seen = measured(board)
    return sorted(
        seen.items(),
        key=lambda kv: (rate(kv[1]), rate(kv[1]) - rate(kv[1], "without_skill"), kv[0]),
    )


def extract(dest, skill):
    """This repository's HEAD, only what measuring one skill needs."""
    os.makedirs(dest)
    paths = ["bin", "plugins", "Makefile", os.path.join("evals", skill)]
    if os.path.isfile(os.path.join(KIT, "evals", ".pending")):
        paths.append(os.path.join("evals", ".pending"))
    arc = subprocess.run(
        ["git", "-C", KIT, "archive", "HEAD", *paths], capture_output=True, check=True
    )
    subprocess.run(["tar", "-x", "-C", dest], input=arc.stdout, check=True)


def held_out(skill):
    """The ids of the skill's held-out cases (evals.json "held_out": true)."""
    try:
        cases = json.load(open(os.path.join(KIT, "evals", skill, "evals.json")))["evals"]
    except (OSError, ValueError, KeyError):
        return set()
    return {str(c["id"]) for c in cases if c.get("held_out")}


def case_id(case_dir):
    """eval-<id>-<slug> -> <id>"""
    parts = os.path.basename(case_dir).split("-")
    return parts[1] if len(parts) > 1 else ""


def failures(skill):
    """The expectations the skill's last measurement failed, with evidence;
    never from a held-out case."""
    hidden = held_out(skill)
    its = sorted(
        glob.glob(os.path.join(WS, skill, "iteration-*")),
        key=lambda p: int(p.rsplit("-", 1)[1]) if p.rsplit("-", 1)[1].isdigit() else 0,
    )
    if not its:
        return []
    out = []
    for g in sorted(
        glob.glob(
            os.path.join(its[-1], "eval-*", "with_skill", "run-1", "grading.json")
        )
    ):
        case = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(g))))
        if case_id(case) in hidden:
            continue
        for e in json.load(open(g)).get("expectations", []):
            if not e.get("passed"):
                out.append(f"- {case}: {e.get('text')} (evidence: {e.get('evidence')})")
    return out


def propose(skill_dir, rationale, fails, args, hidden_dirs=()):
    """skill_dir is a bare copy of the skill folder, outside any kit copy;
    hidden_dirs (every evals/ folder) are unreadable in the sandbox."""
    d = run_driver()
    told = (
        "\n".join(fails)
        if fails
        else "(no graded failures are on this machine; judge from SKILL.md alone)"
    )
    prompt = f"""You improve one skill of a developer workflow kit. Its folder is your working directory:
  {skill_dir}
Read SKILL.md and the files it points to. The skill's last measurement failed these expectations:
{told}

Make the smallest edit to the files in this folder that would make a run following the skill pass
them, without making it worse at anything else. Keep the frontmatter name; keep the description
under 220 characters; keep SKILL.md under 200 lines (put detail in references/); never use an em
dash; never add a tool the frontmatter's allowed-tools does not grant. Edit nothing outside this
folder. The evaluation cases are not yours to read. Then write {rationale} with what you changed
and which failure each change answers.
If you find no edit worth making, change nothing and say so in {rationale}.
Reply with one line: done, or why you stopped."""
    cmd = [
        CLAUDE,
        "-p",
        prompt,
        "--output-format",
        "json",
        "--setting-sources",
        "",
        "--settings",
        json.dumps(no_read(d.settings_for([os.path.dirname(rationale)]), hidden_dirs)),
        "--permission-mode",
        "acceptEdits",
        "--disallowedTools",
        d.OFF,
        "--no-session-persistence",
        "--add-dir",
        os.path.dirname(rationale),
    ]
    if args.model:
        cmd += ["--model", args.model]
    p = subprocess.run(
        cmd, cwd=skill_dir, capture_output=True, text=True, timeout=args.timeout
    )
    return p.returncode == 0, (p.stderr or p.stdout).strip()[-300:]


def no_read(settings, dirs):
    """settings with dirs added to the sandbox's denyRead."""
    fs = settings["sandbox"]["filesystem"]
    fs["denyRead"] = list(fs.get("denyRead", [])) + [os.path.abspath(x) for x in dirs]
    return settings


def held_rate(out, skill, hidden):
    """with_skill pass rate over the held-out cases of one measurement, or None."""
    rates = []
    for g in glob.glob(os.path.join(out, "ws", skill, "iteration-*", "eval-*", "with_skill", "run-1", "grading.json")):
        case = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(g))))
        if case_id(case) in hidden:
            try:
                rates.append(float(json.load(open(g))["summary"]["pass_rate"]))
            except (OSError, ValueError, KeyError):
                pass
    return sum(rates) / len(rates) if rates else None


def em_dashes(root):
    bad = []
    for dp, _, fs in os.walk(root):
        for f in fs:
            p = os.path.join(dp, f)
            try:
                if EM_DASH in open(p, encoding="utf-8").read():
                    bad.append(os.path.relpath(p, root))
            except (UnicodeDecodeError, OSError):
                continue
    return bad


def lint(cand, skill_dir):
    cmd = os.environ.get("BRG_SKILL_TUNE_LINT")
    p = subprocess.run(
        shlex.split(cmd)
        if cmd
        else ["make", "lint-skills", "lint-skill-size", "lint-tools"],
        cwd=cand,
        capture_output=True,
        text=True,
    )
    bad = em_dashes(skill_dir)
    if p.returncode != 0:
        return f"lint failed: {(p.stdout + p.stderr).strip()[-300:]}"
    return f"lint failed: em dash in {', '.join(bad)}" if bad else None


def measure(kit, skill, out, args):
    env = dict(os.environ)
    env["BRG_SKILL_EVALS_WS"] = os.path.join(out, "ws")
    env["BRG_SKILL_EVALS_PRIVATE"] = os.path.join(out, "private.json")
    cmd = os.environ.get("BRG_SKILL_TUNE_MEASURE")
    base = (
        shlex.split(cmd) + [kit]
        if cmd
        else [sys.executable, os.path.join(kit, "bin", "skill-evals-run.py")]
    )
    extra = ["-j", str(args.j)] + (["--model", args.model] if args.model else [])
    p = subprocess.run(
        base + ["--only", skill, "--out", out, *extra],
        capture_output=True,
        text=True,
        env=env,
    )
    sys.stdout.write(p.stdout)
    try:
        m = json.load(open(os.path.join(out, "summary.json")))["skills"][skill]
    except (OSError, ValueError, KeyError):
        return None
    return None if "error" in m else m


def mean(ms, arm):
    return sum(rate(m, arm) for m in ms) / len(ms)


def diff(base_skill, cand_skill, rel, work):
    """A patch with this repository's paths, for `git apply`."""
    g = [
        "git",
        "-C",
        work,
        "-c",
        "user.name=skill-tune",
        "-c",
        "user.email=skill-tune@localhost",
        "-c",
        "commit.gpgsign=false",
    ]
    shutil.copytree(base_skill, os.path.join(work, rel))
    subprocess.run(["git", "init", "-q", work], check=True)
    subprocess.run(g + ["add", "-A"], check=True)
    subprocess.run(g + ["commit", "-q", "-m", "base"], check=True)
    shutil.rmtree(os.path.join(work, rel))
    shutil.copytree(cand_skill, os.path.join(work, rel))
    subprocess.run(g + ["add", "-A"], check=True)
    return subprocess.run(
        g + ["diff", "--cached"], capture_output=True, text=True, check=True
    ).stdout


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--skill")
    ap.add_argument("--board", default=BOARD)
    ap.add_argument("--out", default=os.path.join(KIT, ".scratch", "skill-tune"))
    ap.add_argument("--repeat", type=int, default=1)
    ap.add_argument("-j", type=int, default=3, help="claude sessions per measurement; all measurements run at once")
    ap.add_argument("--min-gain", type=float, default=0.10)
    ap.add_argument("--model")
    ap.add_argument("--timeout", type=int, default=1800)
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    ranked = rank(args.board)
    if args.list:
        for s, m in ranked:
            print(
                f"{s}: with_skill {rate(m):.0%}, without {rate(m, 'without_skill'):.0%}, measured {m.get('date')}"
            )
        print(f"skill-tune: {len(ranked)} measured skills")
        return 0 if ranked else 1
    skill = args.skill or (ranked[0][0] if ranked else None)
    if not skill:
        print(
            "skill-tune: 0 measured skills on the board; run skill-evals-run first",
            file=sys.stderr,
        )
        return 1
    src = kit_paths.skill_dir(skill)
    if not src or not os.path.isfile(os.path.join(KIT, "evals", skill, "evals.json")):
        print(f"skill-tune: {skill} is not a skill with evals", file=sys.stderr)
        return 1
    rel = os.path.relpath(str(src), KIT)
    run = os.path.join(args.out, f"{skill}-{datetime.datetime.now():%Y%m%d-%H%M%S}")
    base, cand = os.path.join(run, "baseline"), os.path.join(run, "candidate")
    extract(base, skill)
    extract(cand, skill)
    cand_skill = os.path.join(cand, rel)
    rationale = os.path.join(run, "rationale.md")
    print(
        f"skill-tune: {skill}: proposing an edit in {os.path.relpath(cand_skill, KIT)}",
        flush=True,
    )

    def reject(why):
        print(f"skill-tune: {skill}: rejected: {why}")
        with open(os.path.join(run, "verdict.json"), "w") as f:
            json.dump({"skill": skill, "kept": False, "why": why}, f, indent=1)
        return 3

    bare = os.path.join(run, "proposal", os.path.basename(rel))
    shutil.copytree(cand_skill, bare)
    hidden = held_out(skill)
    ok, tail = propose(bare, rationale, failures(skill), args,
                       hidden_dirs=[os.path.join(KIT, "evals"), os.path.join(base, "evals"), os.path.join(cand, "evals")])
    shutil.rmtree(cand_skill)
    shutil.copytree(bare, cand_skill)
    if not ok:
        print(f"skill-tune: {skill}: proposer failed: {tail}", file=sys.stderr)
        return 1
    patch = diff(os.path.join(base, rel), cand_skill, rel, os.path.join(run, "diff"))
    if not patch.strip():
        return reject("no edit proposed")
    why = lint(cand, cand_skill)
    if why:
        return reject(why)

    # Every measurement (each repeat of the skill as it is and of the copy)
    # runs at once; each caps its own sessions at -j.
    jobs = [(kit, name, k) for k in range(1, max(1, args.repeat) + 1)
            for kit, name in ((base, "baseline"), (cand, "candidate"))]
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(jobs)) as pool:
        got = list(pool.map(lambda j: measure(j[0], skill, os.path.join(run, f"{j[1]}-{j[2]}"), args), jobs))
    bm, cm = [], []
    for (kit, name, k), m in zip(jobs, got):
        if m is None:
            print(f"skill-tune: {skill}: the {name} measurement failed", file=sys.stderr)
            return 1
        (bm if name == "baseline" else cm).append(m)
    b, c = mean(bm, "with_skill"), mean(cm, "with_skill")
    b_margin, c_margin = b - mean(bm, "without_skill"), c - mean(cm, "without_skill")
    line = f"with_skill {b:.0%} -> {c:.0%}, margin over no skill {b_margin:+.0%} -> {c_margin:+.0%} ({len(bm)} runs each)"
    print(f"skill-tune: {skill}: {line}")
    hb = [r for r in (held_rate(os.path.join(run, f"baseline-{k}"), skill, hidden) for k in range(1, max(1, args.repeat) + 1)) if r is not None]
    hc = [r for r in (held_rate(os.path.join(run, f"candidate-{k}"), skill, hidden) for k in range(1, max(1, args.repeat) + 1)) if r is not None]
    if hidden and hb and hc:
        hb_m, hc_m = sum(hb) / len(hb), sum(hc) / len(hc)
        line += f"; held-out cases {hb_m:.0%} -> {hc_m:.0%}"
        print(f"skill-tune: {skill}: held-out cases (never shown to the proposer) {hb_m:.0%} -> {hc_m:.0%}")
        if hc_m < hb_m:
            return reject(f"{line}; the held-out cases fell")
    elif not hidden:
        print(f"skill-tune: {skill}: no held-out case; the verdict rests on the cases the proposer saw")
    if c - b < args.min_gain or c_margin < b_margin:
        return reject(f"{line}; needs {args.min_gain:.0%} more and no smaller margin")

    with open(os.path.join(run, "candidate.patch"), "w") as f:
        f.write(patch)
    said = (
        open(rationale).read().strip()
        if os.path.isfile(rationale)
        else "(no rationale written)"
    )
    with open(os.path.join(run, "report.md"), "w") as f:
        f.write(
            f"# skill-tune: {skill}\n\n{line}\n\n## Why\n\n{said}\n\n## Apply\n\n"
            f"    git apply {os.path.relpath(os.path.join(run, 'candidate.patch'), KIT)}\n"
        )
    with open(os.path.join(run, "verdict.json"), "w") as f:
        json.dump(
            {"skill": skill, "kept": True, "baseline": b, "candidate": c}, f, indent=1
        )
    print(
        f"skill-tune: {skill}: kept; patch in {os.path.relpath(os.path.join(run, 'candidate.patch'), KIT)}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
