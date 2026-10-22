#!/usr/bin/env python3
"""skill-evals-run: measure a rotating set of skills with no one at the keyboard.

For each chosen skill this drives bin/skill-evals.py end to end: prepare (the
next free iteration), one `claude -p` executor per run folder, timing from the
session's JSON result, grade-prompt, one `claude -p` grader per case, unblind
and measure. The measurements go to <out>/summary.json, which
bin/eval-scoreboard.py --skill-evals copies into evals/scoreboard.jsonl.

Every session runs in Claude Code's Bash sandbox (required, network limited to
localhost, credential folders unreadable) with no user or project settings,
and without the Skill tool or browser tools. The executor prompt forbids push,
deploy and network installs; the sandbox enforces it.

Rotation, from the board's skill_evals rows: skills whose skill folder or
evals/<name>/ changed since the commit they were last measured at come first,
then skills never measured, then the longest since measured. --max caps it.

Usage: skill-evals-run.py [--only a,b] [--max N] [--board F] [--out D]
                          [-j N] [--model M] [--timeout S] [--list]
Prints one line per skill and "skill-evals-run: N skills chosen, M measured,
K failed"; exits 1 when no skill was chosen or none was measured or any
failed. Uses the logged-in claude CLI (subscription), never an API key.
"""

import argparse
import concurrent.futures
import datetime
import glob
import json
import os
import re
import subprocess
import sys

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(KIT, "bin"))
import kit_paths  # noqa: E402

CLAUDE = os.environ.get("BRG_CLAUDE", "claude")
EVALS = os.path.join(KIT, "bin", "skill-evals.py")
WS = os.environ.get("BRG_SKILL_EVALS_WS") or os.path.join(
    KIT, ".scratch", "skill-evals"
)
PRIVATE = os.environ.get("BRG_SKILL_EVALS_PRIVATE") or os.path.join(
    KIT, ".scratch", "private", "comparisons.json"
)
BOARD = os.path.join(KIT, "evals", "scoreboard.jsonl")

SANDBOX = {
    "sandbox": {
        "enabled": True,
        "failIfUnavailable": True,
        "autoAllowBashIfSandboxed": True,
        "allowUnsandboxedCommands": False,
        "network": {
            "allowedDomains": ["localhost", "127.0.0.1"],
            "allowLocalBinding": True,
        },
        "filesystem": {
            "denyRead": [
                "~/.ssh",
                "~/.aws",
                "~/.config/gcloud",
                "~/.kube",
                "~/.config/bearing",
                "~/.docker/config.json",
                "~/.netrc",
                "~/.git-credentials",
            ],
            "denyWrite": ["~/.ssh", "~/.config/bearing", "~/.gitconfig"],
        },
    }
}
OFF = "Skill,WebFetch,WebSearch,mcp__plugin_playwright_playwright,mcp__claude-in-chrome,mcp__Claude_Browser"


def git(*args):
    p = subprocess.run(["git", "-C", KIT, *args], capture_output=True, text=True)
    return p.stdout.strip() if p.returncode == 0 else None


def skills_with_evals():
    names = {d.name for d in kit_paths.skill_dirs()}
    return sorted(
        n for n in names if os.path.isfile(os.path.join(KIT, "evals", n, "evals.json"))
    )


def last_measured(board):
    """skill -> its newest measurement in the board (rows are oldest first)."""
    out = {}
    if os.path.isfile(board):
        with open(board) as f:
            for line in f:
                if not line.strip():
                    continue
                se = json.loads(line).get("skill_evals") or {}
                for s, m in (se.get("skills") or {}).items():
                    if m.get("arms"):
                        out[s] = m
    return out


def changed_since(skill, commit):
    """None when unchanged since commit, else the reason it goes first."""
    paths = [
        os.path.relpath(str(kit_paths.skill_dir(skill)), KIT),
        os.path.join("evals", skill),
    ]
    log = git("log", "--format=%h", f"{commit}..HEAD", "--", *paths)
    if log is None:
        # git could not answer (an unknown commit after a rewrite, or a
        # repository git refuses to read): measure it again, and say why.
        return f"history unreadable from {commit[:7] or 'unknown'}"
    return f"changed since {commit[:7]}" if log else None


def choose(args):
    pool = skills_with_evals()
    if args.only:
        want = [s.strip() for s in args.only.split(",")]
        return [(s, "asked for") for s in want if s in pool]
    seen = last_measured(args.board)
    changed, never, old = [], [], []
    for s in pool:
        m = seen.get(s)
        if not m:
            never.append((s, "never measured"))
        elif why := changed_since(s, m.get("commit") or ""):
            changed.append((s, why))
        else:
            old.append((m.get("date") or "", s))
    old.sort()
    rest = [(s, f"last measured {d}") for d, s in old]
    return (changed + never + rest)[: max(0, args.max)]


def evals(*args):
    return subprocess.run(
        [sys.executable, EVALS, *args], capture_output=True, text=True
    )


def settings_for(writable):
    """The sandbox settings, with these folders writable as well as the cwd."""
    s = json.loads(json.dumps(SANDBOX))
    if writable:
        s["sandbox"]["filesystem"]["allowWrite"] = list(writable)
    return s


def claude(prompt, cwd, args, writable=(), keep=None):
    """One sandboxed session in cwd; writable folders outside it are added to
    both the sandbox and the session's directories. keep is a file the JSON
    result is saved to, so a failed run can be read afterwards."""
    cmd = [
        CLAUDE,
        "-p",
        prompt,
        "--output-format",
        "json",
        "--setting-sources",
        "",
        "--settings",
        json.dumps(settings_for(writable)),
        "--permission-mode",
        "acceptEdits",
        "--disallowedTools",
        OFF,
        "--no-session-persistence",
    ]
    for w in writable:
        cmd += ["--add-dir", w]
    if args.model:
        cmd += ["--model", args.model]
    try:
        p = subprocess.run(
            cmd, cwd=cwd, capture_output=True, text=True, timeout=args.timeout
        )
    except subprocess.TimeoutExpired:
        return None, f"timed out after {args.timeout} s"
    if keep:
        with open(keep, "w") as f:
            f.write(p.stdout)
    try:
        res = json.loads(p.stdout.strip().splitlines()[-1])
    except (ValueError, IndexError):
        return (
            None,
            f"claude exit {p.returncode}, no JSON result: {p.stderr.strip()[:200]}",
        )
    if p.returncode != 0 or res.get("is_error"):
        return None, f"claude exit {p.returncode}: {str(res.get('result'))[:200]}"
    return res, None


def next_iteration(skill):
    found = [
        int(m.group(1))
        for d in glob.glob(os.path.join(WS, skill, "iteration-*"))
        if (m := re.search(r"iteration-(\d+)$", d))
    ]
    return max(found, default=0) + 1


def measure_one(skill, args):
    it = str(next_iteration(skill))
    p = evals("prepare", skill, "--iteration", it)
    if p.returncode != 0:
        return {"error": f"prepare: {(p.stderr or p.stdout).strip()[:200]}"}
    runs = [
        os.path.join(KIT, ln.strip()) for ln in p.stdout.splitlines()[1:] if ln.strip()
    ]
    model = args.model

    def execute(rd):
        with open(os.path.join(rd, "prompt.txt")) as f:
            prompt = f.read()
        # The run folder holds transcript.md, outside the repository the run
        # works in; it is the only other place the session may write.
        res, err = claude(prompt, os.path.join(rd, "outputs", "repo"), args,
                          writable=[rd], keep=os.path.join(rd, "session.json"))
        if err:
            return err
        if not os.path.isfile(os.path.join(rd, "transcript.md")):
            said = str((res or {}).get("result") or "")[:200]
            return f"{os.path.relpath(rd, WS)}: no transcript.md (the session said: {said})"
        u = res.get("usage") or {}
        tokens = sum(
            int(u.get(k) or 0)
            for k in (
                "input_tokens",
                "output_tokens",
                "cache_creation_input_tokens",
                "cache_read_input_tokens",
            )
        )
        t = evals("timing", rd, str(tokens), str(int(res.get("duration_ms") or 0)))
        return None if t.returncode == 0 else f"timing: {t.stderr.strip()[:200]}"

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.j)) as pool:
        errors = [e for e in pool.map(execute, runs) if e]
    if errors:
        return {
            "error": f"{len(errors)} of {len(runs)} runs failed; first: {errors[0]}"
        }

    g = evals("grade-prompt", skill, "--iteration", it)
    if g.returncode != 0:
        return {"error": f"grade-prompt: {(g.stderr or g.stdout).strip()[:200]}"}
    briefs = sorted(
        glob.glob(
            os.path.join(WS, skill, f"iteration-{it}", "eval-*", "grader_prompt.txt")
        )
    )

    def grade(path):
        with open(path) as f:
            res, err = claude(f.read(), os.path.dirname(path), args)
        return err

    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.j)) as pool:
        errors = [e for e in pool.map(grade, briefs) if e]
    if errors:
        return {
            "error": f"{len(errors)} of {len(briefs)} graders failed; first: {errors[0]}"
        }

    for step in (
        ["unblind", skill, "--iteration", it],
        ["measure", skill, "--iteration", it, "--model", model or "cli-default"],
    ):
        r = evals(*step)
        if r.returncode != 0:
            return {"error": f"{step[0]}: {(r.stderr or r.stdout).strip()[:200]}"}
    with open(PRIVATE) as f:
        m = json.load(f)[skill]["measured"]
    m["commit"] = git("rev-parse", "HEAD")
    return m


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--only", help="comma-separated skill names (skips the rotation)")
    ap.add_argument("--max", type=int, default=5)
    ap.add_argument("--board", default=BOARD)
    ap.add_argument("--out", default=os.path.join(KIT, ".scratch", "skill-evals-run"))
    ap.add_argument("-j", type=int, default=4)
    ap.add_argument("--model")
    ap.add_argument("--timeout", type=int, default=1800, help="seconds per session")
    ap.add_argument(
        "--list", action="store_true", help="print the chosen skills and stop"
    )
    args = ap.parse_args()

    chosen = choose(args)
    if args.list:
        for s, why in chosen:
            print(f"{s} ({why})")
        print(f"skill-evals-run: {len(chosen)} skills chosen")
        return 0 if chosen else 1
    if not chosen:
        print("skill-evals-run: 0 skills chosen; nothing measured", file=sys.stderr)
        return 1

    summary = {
        "date": datetime.date.today().isoformat(),
        "commit": git("rev-parse", "HEAD"),
        "chosen": [s for s, _ in chosen],
        "skills": {},
    }
    for s, why in chosen:
        print(f"{s}: measuring ({why})", flush=True)
        m = measure_one(s, args)
        summary["skills"][s] = m
        if "error" in m:
            print(f"{s}: failed: {m['error']}", flush=True)
        else:
            arms = ", ".join(f"{k} {v['pass_rate']:.2f}" for k, v in m["arms"].items())
            print(f"{s}: {arms}; {m['result']}", flush=True)
    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "summary.json"), "w") as f:
        json.dump(summary, f, indent=1)
    failed = sum("error" in m for m in summary["skills"].values())
    measured = len(chosen) - failed
    print(
        f"skill-evals-run: {len(chosen)} skills chosen, {measured} measured, {failed} failed; "
        f"summary in {os.path.relpath(os.path.join(args.out, 'summary.json'), KIT)}"
    )
    return 0 if measured and not failed else 1


if __name__ == "__main__":
    sys.exit(main())
