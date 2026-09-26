#!/usr/bin/env python3
"""skill-evals: run a Bearing skill's evals against no skill and its best
alternative, graded blind, and record the measured result.

The cases live in evals/<name>/evals.json, away from the skill so a run that
follows the skill cannot read its grading (skill-creator's case schema;
`files[0]` is a fixture repository under evals/<name>/files/, whose optional
.eval-branch names the branch to check out). The workspace is
.scratch/skill-evals/<name>/iteration-<N>/, one folder per case, one per
arm inside it, in the layout skill-creator's aggregate_benchmark.py reads.

Arms:
  with_skill            reads the kit's SKILL.md from this checkout and follows it
  with_the_alternative  loads the best alternative from docs/comparisons.json
                        (skipped when there is none, or it is another Bearing skill)
  without_skill         no skill at all
Folders are named arm-1..arm-3 until grading is done, so the grader does not
know which arm produced what; `unblind` renames them. The benchmark's delta is
the first two configurations in sorted order: with_skill against the
alternative when there is one, else against no skill.

  skill-evals.py prepare <skill> [--iteration N]   workspace, fixtures, prompts
  skill-evals.py reset <run dir>...               rebuild interrupted runs from the fixture
  skill-evals.py timing <run dir> <tokens> <ms>    record a finished run
  skill-evals.py grade-prompt <skill> [--iteration N]
                                                   one blind grader brief per case
  skill-evals.py unblind <skill> [--iteration N]   arm-k -> arm name
  skill-evals.py measure <skill> [--iteration N] --model <id>
                                                   benchmark + comparisons.json
  skill-evals.py status                            where the 98 stand

Each command prints the count of what it handled and exits 1 on zero.
"""

import argparse
import datetime
import json
import os
import random
import re
import shutil
import subprocess
import sys

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WS = os.path.join(KIT, ".scratch", "skill-evals")
COMPARISONS = os.path.join(KIT, "docs", "comparisons.json")
ARMS = ["with_skill", "with_the_alternative", "without_skill"]


def die(msg):
    print(msg, file=sys.stderr)
    sys.exit(1)


def load(path):
    with open(path, encoding="utf-8") as f:
        return json.load(f)


def dump(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, ensure_ascii=False)
        f.write("\n")


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")[:48]


def bearing_skills():
    """The Bearing skills: every directory under skills/ that holds a SKILL.md."""
    root = os.path.join(KIT, "skills")
    return sorted(
        d for d in os.listdir(root) if os.path.isfile(os.path.join(root, d, "SKILL.md"))
    )


def alternative(skill):
    """The invoke name of the best alternative, or None when there is no arm for it."""
    c = load(COMPARISONS).get(skill, {})
    b = c.get("best_alternative") or {}
    inv = (b.get("invoke") or "").strip()
    if not inv or not b.get("installed") or inv.lstrip("/") in bearing_skills():
        return None
    if user_only(inv):
        # A skill marked disable-model-invocation refuses the Skill tool, so an
        # unattended arm can only stop; measure against no skill instead.
        return None
    return inv


def user_only(inv):
    """True when every installed copy of the skill is user-invocable only."""
    name = inv.lstrip("/").split(":")[-1]
    found = []
    for root in (
        os.path.expanduser("~/.claude/plugins"),
        os.path.expanduser("~/.claude/skills"),
    ):
        for dp, dns, fns in os.walk(root):
            dns[:] = [d for d in dns if not d.startswith(".") and d != "node_modules"]
            if os.path.basename(dp) == name and "SKILL.md" in fns:
                with open(
                    os.path.join(dp, "SKILL.md"), encoding="utf-8", errors="replace"
                ) as f:
                    head = f.read(4000).split("\n---", 1)[0]
                found.append(
                    re.search(r"^disable-model-invocation:\s*true", head, re.M)
                    is not None
                )
    return bool(found) and all(found)


def git(repo, *args):
    subprocess.run(
        [
            "git",
            "-C",
            repo,
            "-c",
            "user.name=eval",
            "-c",
            "user.email=eval@localhost",
            *args,
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def executor_prompt(skill, arm, alt, case, repo, run_dir):
    common = f"""You are one run of a skill evaluation. A user typed the request below in the repository at
  {repo}
Work only inside that repository (read, edit and run commands there). Nobody is available to answer
questions: where you would ask the user something, pick the option you would recommend, and note
the question and your choice. Where a procedure says to stop and wait for the user's agreement or
answer before going on, carry on with your recommended option as a working assumption so the whole
task is finished in this run, and record the question and the assumption. The user has not decided
anything: any decision record, ADR or document you write shows such a choice as Proposed (awaiting
the user), never Accepted or approved, and names no person as having decided or authored it.
Never push, deploy or publish anything; nothing outside the repository may change. Do not install
packages from the network. If a procedure starts helper agents, run each in the foreground and wait
for its result (never in the background): a background helper's completion notice does not reach
you, and a run that waits for one never finishes.

The request:
---
{case["prompt"]}
---
"""
    if arm == "with_skill":
        how = f"""How to work: read {KIT}/skills/{skill}/SKILL.md and follow it as your procedure, reading the
files it points to. Wherever it says ${{CLAUDE_PLUGIN_ROOT}}, use {KIT}. Do not use the Skill tool
for any Bearing skill (bearing:<name>; the installed copy is an older version); read the file instead. Do not load any
other skill. Never open anything under {KIT}/evals/: it holds the grading for this
run, and reading it spoils the run."""
    elif arm == "with_the_alternative":
        how = f"""How to work: load the skill `{alt}` with the Skill tool and follow it as your procedure. Do not
load or read any Bearing skill (bearing:<name>), and do not read anything under {KIT}."""
    else:
        how = f"""How to work: use your own judgement. Do not use the Skill tool, and do not read any SKILL.md
file or anything under {KIT} or ~/.claude."""
    return f"""{common}
{how}

When you are done, write {run_dir}/transcript.md with: the steps you took in order, each command you
ran with the part of its output that mattered, every question you would have asked and what you
chose, and the final message you would give the user. Describe what you did; do not name which
skill or instructions you followed. Then reply with one line: done, or the reason you stopped.
"""


def prepare(a):
    ed_src = os.path.join(KIT, "evals", a.skill)
    ev = os.path.join(ed_src, "evals.json")
    if not os.path.isfile(ev):
        die(
            f"skill-evals: {a.skill} has no evals/{a.skill}/evals.json, nothing prepared"
        )
    data = load(ev)
    alt = alternative(a.skill)
    arms = ARMS if alt else [x for x in ARMS if x != "with_the_alternative"]
    it = os.path.join(WS, a.skill, f"iteration-{a.iteration}")
    if os.path.exists(it):
        die(f"skill-evals: {it} exists; use --iteration {a.iteration + 1}")
    runs = []
    for case in data["evals"]:
        name = case.get("name") or f"case-{case['id']}"
        ed = os.path.join(it, f"eval-{case['id']}-{slug(name)}")
        os.makedirs(ed)
        dump(
            os.path.join(ed, "eval_metadata.json"),
            {
                "eval_id": case["id"],
                "eval_name": name,
                "prompt": case["prompt"],
                "assertions": case["expectations"],
            },
        )
        order = list(arms)
        random.Random(f"{a.skill}:{case['id']}:{a.iteration}").shuffle(order)
        mapping = {f"arm-{i + 1}": arm for i, arm in enumerate(order)}
        dump(os.path.join(ed, "arms.json"), mapping)
        fixture = os.path.join(ed_src, case["files"][0]) if case.get("files") else None
        for blind, arm in mapping.items():
            rd = os.path.join(ed, blind, "run-1")
            repo = os.path.join(rd, "outputs", "repo")
            build_repo(fixture, repo)
            with open(os.path.join(rd, "prompt.txt"), "w", encoding="utf-8") as f:
                f.write(executor_prompt(a.skill, arm, alt, case, repo, rd))
            runs.append(rd)
    print(
        f"skill-evals: {a.skill} iteration {a.iteration}: {len(data['evals'])} cases x {len(arms)} arms"
        f" ({', '.join(arms)}{'; alternative ' + alt if alt else '; no alternative arm'}) = {len(runs)} runs"
    )
    for r in runs:
        print(os.path.relpath(r, KIT))
    return 0 if runs else 1


def build_repo(fixture, repo):
    """Copy the fixture to repo and commit it as the tag `fixture`."""
    if fixture and os.path.isdir(fixture):
        shutil.copytree(fixture, repo)
    else:
        os.makedirs(repo)
    # A fixture keeps files a secret scanner or the guard would refuse (an
    # env file with planted fake keys) as `dot<name>.evalfile`; the run sees
    # them as `.<name>`.
    for d, _, names in os.walk(repo):
        for n in names:
            if n.endswith(".evalfile"):
                real = n[: -len(".evalfile")]
                if real.startswith("dot"):
                    real = "." + real[3:]
                os.rename(os.path.join(d, n), os.path.join(d, real))
    if os.path.isfile(os.path.join(repo, ".eval-setup.sh")):
        # The fixture builds its own history (branches, remote-tracking refs,
        # an uncommitted edit) and removes the script; the state it leaves is
        # the starting point the grader diffs against.
        subprocess.run(["bash", ".eval-setup.sh"], cwd=repo, check=True)
        git(repo, "tag", "fixture")
        return
    branch = "main"
    bf = os.path.join(repo, ".eval-branch")
    if os.path.isfile(bf):
        branch = open(bf).read().strip() or "main"
        os.remove(bf)
    git(repo, "init", "-q", "-b", branch)
    git(repo, "add", "-A")
    git(repo, "commit", "-q", "--allow-empty", "-m", "fixture")
    git(repo, "tag", "fixture")


def reset(a):
    """Rebuild interrupted runs from their fixtures so they can run again."""
    n = 0
    for rd in a.run_dirs:
        rd = os.path.abspath(rd.rstrip("/"))
        rel = os.path.relpath(rd, WS).split(os.sep)
        if len(rel) != 5 or rel[4] != "run-1" or not rel[2].startswith("eval-"):
            die(f"skill-evals: {rd} is not a run directory under {WS}")
        skill, case_id = rel[0], int(rel[2].split("-")[1])
        case = next(
            c
            for c in load(os.path.join(KIT, "evals", skill, "evals.json"))["evals"]
            if c["id"] == case_id
        )
        fixture = (
            os.path.join(KIT, "evals", skill, case["files"][0])
            if case.get("files")
            else None
        )
        for name in ("transcript.md", "timing.json", "grading.json"):
            if os.path.exists(os.path.join(rd, name)):
                os.remove(os.path.join(rd, name))
        repo = os.path.join(rd, "outputs", "repo")
        if os.path.exists(repo):
            shutil.rmtree(repo)
        build_repo(fixture, repo)
        n += 1
        print(f"skill-evals: reset {os.path.relpath(rd, KIT)}")
    if n == 0:
        die("skill-evals: 0 runs reset")
    return 0


def timing(a):
    if not os.path.isdir(a.run_dir):
        die(f"skill-evals: {a.run_dir} is not a run directory")
    dump(
        os.path.join(a.run_dir, "timing.json"),
        {
            "total_tokens": int(a.tokens),
            "duration_ms": int(a.ms),
            "total_duration_seconds": round(int(a.ms) / 1000, 1),
        },
    )
    print(f"skill-evals: timing written for {a.run_dir}")
    return 0


def grade_prompt(a):
    it = os.path.join(WS, a.skill, f"iteration-{a.iteration}")
    sc = skill_creator()
    if not sc:
        die(
            "skill-evals: skill-creator not found; its agents/grader.md is the grading method"
        )
    n = 0
    for ed in sorted(os.listdir(it)) if os.path.isdir(it) else []:
        d = os.path.join(it, ed)
        if not os.path.isfile(os.path.join(d, "eval_metadata.json")):
            continue
        blinds = sorted(b for b in os.listdir(d) if b.startswith("arm-"))
        missing = [
            b
            for b in blinds
            if not os.path.isfile(os.path.join(d, b, "run-1", "transcript.md"))
        ]
        if missing:
            die(f"skill-evals: {ed}: no transcript.md yet in {', '.join(missing)}")
        meta = load(os.path.join(d, "eval_metadata.json"))
        exp = "\n".join(f"{i + 1}. {e}" for i, e in enumerate(meta["assertions"]))
        arms = "\n".join(f"- {b}: {os.path.join(d, b, 'run-1')}" for b in blinds)
        text = f"""You grade one case of a skill evaluation, blind. Read {sc}/agents/grader.md and follow its
method (steps 1 to 7). Several runs got the same request; grade each run on its own, to the same
standard. Do not try to work out how a run was produced, and do not read arms.json or anything
outside the run folders listed below and the files they contain.

The request each run received:
---
{meta["prompt"]}
---

Expectations (grade every one for every run, text copied exactly into the "text" field):
{exp}

Runs (each holds transcript.md and outputs/repo, a git repository whose starting state is the tag
`fixture`; `git -C <repo> diff fixture` and `git -C <repo> status --porcelain` show what the run
changed, including files it created):
{arms}

You may run read-only commands and the repository's own checks (for example `make check`, `go test ./...`,
`python3 <script>`) inside a run's repository; do not edit, add or delete any file there. An
expectation about a check passing is graded by running it yourself, never by the transcript's word.
The burden of proof is on the expectation: no evidence is a fail. A file with the right name and the
wrong content is a fail.

Write <run folder>/grading.json for every run, in grader.md's format with fields text, passed and
evidence, and the summary block (passed, failed, total, pass_rate). Add "eval_feedback" with any
expectation that was not discriminating or any outcome no expectation covers. Reply with one line per
run: the run folder name and passed/total.
"""
        with open(os.path.join(d, "grader_prompt.txt"), "w", encoding="utf-8") as f:
            f.write(text)
        n += 1
    if n == 0:
        die(f"skill-evals: 0 cases under {it}")
    print(f"skill-evals: {n} grader briefs written")
    return 0


def unblind(a):
    it = os.path.join(WS, a.skill, f"iteration-{a.iteration}")
    n = 0
    for ed in sorted(os.listdir(it)) if os.path.isdir(it) else []:
        mp = os.path.join(it, ed, "arms.json")
        if not os.path.isfile(mp):
            continue
        for blind, arm in load(mp).items():
            src = os.path.join(it, ed, blind)
            if os.path.isdir(src):
                if not os.path.isfile(os.path.join(src, "run-1", "grading.json")):
                    die(
                        f"skill-evals: {src} has no grading.json; grade before unblinding"
                    )
                os.rename(src, os.path.join(it, ed, arm))
                n += 1
    if n == 0:
        die(f"skill-evals: 0 arm folders unblinded under {it}")
    print(f"skill-evals: {n} arm folders unblinded")
    return 0


def skill_creator():
    roots = [os.path.expanduser(p) for p in ("~/.claude", "~/.config/Claude")]
    for root in roots:
        for dp, dns, _ in os.walk(root):
            if dp.endswith(os.path.join("skills", "skill-creator")) and os.path.isfile(
                os.path.join(dp, "scripts", "aggregate_benchmark.py")
            ):
                return dp
            dns[:] = [d for d in dns if not d.startswith(".") and d != "node_modules"]
    return None


def measure(a):
    it = os.path.join(WS, a.skill, f"iteration-{a.iteration}")
    sc = skill_creator()
    if not sc:
        die("skill-evals: skill-creator's aggregate_benchmark.py not found")
    subprocess.run(
        [
            sys.executable,
            "-m",
            "scripts.aggregate_benchmark",
            it,
            "--skill-name",
            a.skill,
        ],
        cwd=sc,
        check=True,
        stdout=subprocess.DEVNULL,
    )
    b = load(os.path.join(it, "benchmark.json"))
    rs = b.get("run_summary", {})
    arms = {k: v for k, v in rs.items() if k in ARMS}
    if "with_skill" not in arms or len(arms) < 2:
        die(
            f"skill-evals: benchmark for {a.skill} has {len(arms)} graded arms; need with_skill and one more"
        )
    cases = len([d for d in os.listdir(it) if d.startswith("eval-")])

    # Tokens and executor time come from each run's timing.json (written from
    # the task notification); graders copy timing without tokens, so the
    # benchmark's own token figure can be zero.
    def run_timing(arm):
        ts = []
        for ed in os.listdir(it):
            tf = os.path.join(it, ed, arm, "run-1", "timing.json")
            if os.path.isfile(tf):
                ts.append(load(tf))
        if not ts:
            return 0, 0.0
        return (
            int(sum(t["total_tokens"] for t in ts) / len(ts)),
            round(sum(t["total_duration_seconds"] for t in ts) / len(ts), 1),
        )

    out = {}
    for k, v in arms.items():
        tok, sec = run_timing(k)
        out[k] = {
            "pass_rate": round(v["pass_rate"]["mean"], 3),
            "tokens": tok,
            "seconds": sec,
        }
    art = out["with_skill"]["pass_rate"]
    rivals = {k: v["pass_rate"] for k, v in out.items() if k != "with_skill"}
    best = max(rivals, key=rivals.get)
    # Rounded so 0.96 - 0.86 counts as the 10 points it is, not 0.0999...
    margin = round(art - rivals[best], 4)
    result = (
        "bearing ahead"
        if margin >= 0.10
        else "rival ahead"
        if margin <= -0.10
        else "within 10 points"
    )
    c = load(COMPARISONS)
    c[a.skill]["measured"] = {
        "date": datetime.date.today().isoformat(),
        "model": a.model,
        "iteration": a.iteration,
        "cases": cases,
        "runs_per_arm": 1,
        "arms": out,
        "result": result,
        "closest": best,
        "margin": round(margin, 3),
    }
    dump(COMPARISONS, c)
    print(
        f"skill-evals: {a.skill} measured on {cases} cases: "
        + ", ".join(f"{k} {v['pass_rate']:.2f}" for k, v in out.items())
        + f"; {result} ({best}, {margin * 100:+.1f} points)"
    )
    return 0


def status(a):
    c = load(COMPARISONS)
    skills = bearing_skills()
    if not skills:
        die("skill-evals: 0 skills found")
    with_evals = [
        s for s in skills if os.path.isfile(os.path.join(KIT, "evals", s, "evals.json"))
    ]
    measured = [s for s in skills if c.get(s, {}).get("measured")]
    print(
        f"skill-evals: {len(skills)} skills, {len(with_evals)} with evals, {len(measured)} measured"
    )
    for s in measured:
        m = c[s]["measured"]
        print(
            f"  {s}: {m['result']} ({m['closest']}, {m['margin'] * 100:+.1f} points) on {m['cases']} cases, {m['date']}"
        )
    todo = [s for s in with_evals if s not in measured]
    if todo:
        print("  evals written, not measured: " + ", ".join(todo))
    return 0


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    sp = ap.add_subparsers(dest="cmd", required=True)
    for name in ("prepare", "grade-prompt", "unblind", "measure"):
        p = sp.add_parser(name)
        p.add_argument("skill")
        p.add_argument("--iteration", type=int, default=1)
        if name == "measure":
            p.add_argument("--model", required=True)
    p = sp.add_parser("reset")
    p.add_argument("run_dirs", nargs="+")
    p = sp.add_parser("timing")
    p.add_argument("run_dir")
    p.add_argument("tokens")
    p.add_argument("ms")
    sp.add_parser("status")
    a = ap.parse_args()
    return {
        "prepare": prepare,
        "reset": reset,
        "timing": timing,
        "grade-prompt": grade_prompt,
        "unblind": unblind,
        "measure": measure,
        "status": status,
    }[a.cmd](a)


if __name__ == "__main__":
    sys.exit(main())
