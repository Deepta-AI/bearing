#!/usr/bin/env python3
"""trigger-eval: does a plain request load the right skill?

Each case in evals/triggers.json is one request sent to a fresh headless
Claude Code session (`claude -p`) with the three Bearing plugins loaded through
--plugin-dir, in a small sample repository. The session is stopped at the first
Skill call, or after a few other tool calls, or when it ends; what counts is
the first Bearing skill Claude loaded.

  should   the skill must be the first Bearing skill loaded
  near     a near miss: the skill must not be loaded; `expect` names the
           sibling that should load instead (or null for none), recorded but
           not required, so a near miss measures false triggers only

By default only the project and local setting sources load, so skills and
plugins installed on this machine do not answer for the kit under test.
--sources user,project,local runs in the machine's real setup instead (every
installed skill competing for the listing budget).

Usage: trigger-eval.py [--only name,...] [--kind should|near] [-j N]
                       [--model M] [--sources S] [--repeat N]
                       [--min-recall R] [--max-false R] [--list]
Prints one line per skill and "trigger-eval: N cases, ..."; exits 1 when no
case ran, when any case errored, or when recall or the false-trigger rate
misses its bound. Results go to .scratch/trigger-eval/<time>/results.json.
Uses the logged-in claude CLI (subscription); one short session per case.
"""

import argparse
import concurrent.futures
import json
import os
import subprocess
import sys
import tempfile
import threading
import time

KIT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLUGINS = [
    os.path.join(KIT, "plugins", p)
    for p in ("bearing", "bearing-backend", "bearing-apps")
]
CASES = os.environ.get("BRG_TRIGGER_CASES", os.path.join(KIT, "evals", "triggers.json"))
CLAUDE = os.environ.get("BRG_CLAUDE", "claude")
TIMEOUT = 150
MAX_OTHER_TOOLS = 3
PLUGIN_NAMES = {"bearing", "bearing-backend", "bearing-apps"}

# Enough of a repository that the requests read naturally; nothing runs.
FIXTURE = {
    "README.md": "# clinic-booking\n\nBook, move and cancel clinic appointments. Go API, Python worker, Next.js web app, Flutter mobile app.\n",
    "Makefile": "check:\n\t@echo check: not wired in this fixture\n",
    "CHANGELOG.md": "# Changelog\n\n## [1.4.0]\n- Waitlist for full slots.\n",
    "services/api/go.mod": "module example.com/clinic/api\n\ngo 1.23\n",
    "services/api/main.go": 'package main\n\nimport "net/http"\n\nfunc main() {\n\thttp.HandleFunc("/appointments", listAppointments)\n\thttp.ListenAndServe(":8080", nil)\n}\n',
    "services/api/appointments.go": 'package main\n\nimport "net/http"\n\nfunc listAppointments(w http.ResponseWriter, r *http.Request) {\n\t// SELECT * FROM appointments WHERE clinic_id = $1\n\tw.WriteHeader(http.StatusOK)\n}\n',
    "services/api/migrations/0007_waitlist.sql": "CREATE TABLE waitlist (id bigserial PRIMARY KEY, patient_id bigint NOT NULL, slot_id bigint NOT NULL);\n",
    "services/worker/pyproject.toml": '[project]\nname = "worker"\nversion = "0.1.0"\ndependencies = ["celery", "psycopg"]\n',
    "services/worker/reminders.py": "def send_reminders(conn):\n    for row in conn.execute('select * from appointments where starts_at < now() + interval \\'1 day\\''):\n        print(row)\n",
    "web/package.json": '{"name": "web", "private": true, "dependencies": {"next": "15.0.0", "react": "19.0.0"}}\n',
    "web/app/page.tsx": "export default function Home() {\n  return <main>Book an appointment</main>;\n}\n",
    "mobile/pubspec.yaml": "name: clinic_mobile\nenvironment:\n  sdk: '>=3.4.0 <4.0.0'\ndependencies:\n  flutter:\n    sdk: flutter\n",
    "mobile/lib/main.dart": "import 'package:flutter/material.dart';\n\nvoid main() => runApp(const MaterialApp(home: Text('Clinic')));\n",
    "infra/main.tf": 'resource "aws_db_instance" "main" {\n  engine = "postgres"\n}\n',
    "infra/k8s/api.yaml": "apiVersion: apps/v1\nkind: Deployment\nmetadata:\n  name: api\n",
    "docs/prd/waitlist.md": "# Waitlist\n\nPatients join a waitlist when a slot is full and get offered a freed slot.\n",
    "docs/adr/0001-postgres.md": "# 1. Postgres for bookings\n\nStatus: Accepted\n",
    ".github/workflows/ci.yml": "name: ci\non: [push]\njobs:\n  test:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - run: make check\n",
}


def build_fixture(root):
    d = os.path.join(root, "clinic-booking")
    for rel, text in FIXTURE.items():
        p = os.path.join(d, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        with open(p, "w") as f:
            f.write(text)
    git = ["-c", "user.email=eval@example.com", "-c", "user.name=eval"]
    for args in (
        ["init", "-q", "-b", "main"],
        ["add", "-A"],
        [*git, "commit", "-q", "-m", "init"],
    ):
        subprocess.run(["git", *args], cwd=d, capture_output=True)
    return d


def skill_name(raw):
    """'bearing-backend:go' -> ('bearing-backend', 'go'); a bare name has no plugin."""
    plugin, _, name = raw.rpartition(":")
    return plugin, name


def run_case(cwd, prompt, args):
    cmd = [CLAUDE, "-p", prompt]
    for p in PLUGINS:
        cmd += ["--plugin-dir", p]
    cmd += [
        "--setting-sources",
        args.sources,
        "--allowedTools",
        # Read-only git too: a request like "get this branch ready" looks at the
        # branch first, and a denied command ends the session before a skill loads.
        "Skill,Read,Grep,Glob,Bash(git status:*),Bash(git log:*),Bash(git diff:*),Bash(git branch:*),Bash(git show:*),Bash(ls:*)",
        "--output-format",
        "stream-json",
        "--verbose",
        "--no-session-persistence",
    ]
    if args.model:
        cmd += ["--model", args.model]
    skills, others, tools, error, events, t0 = [], 0, [], "", 0, time.time()
    err = tempfile.TemporaryFile(mode="w+")  # a file, so a chatty stderr never blocks
    p = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=err, text=True)
    timer = threading.Timer(TIMEOUT, p.kill)
    timer.start()
    try:
        for line in p.stdout:
            try:
                ev = json.loads(line)
            except ValueError:
                continue
            events += 1
            if ev.get("type") == "result":
                if ev.get("is_error"):
                    error = str(ev.get("result", "error"))[:200]
                break
            if ev.get("type") != "assistant":
                continue
            for c in (ev.get("message") or {}).get("content") or []:
                if c.get("type") != "tool_use":
                    continue
                if c.get("name") == "Skill":
                    skills.append(str((c.get("input") or {}).get("skill", "")))
                else:
                    others += 1
                    inp = c.get("input") or {}
                    tools.append(f"{c.get('name')}: {str(inp.get('command') or inp.get('file_path') or inp.get('pattern') or '')[:60]}")
            if (
                any(skill_name(s)[0] in PLUGIN_NAMES for s in skills)
                or others >= MAX_OTHER_TOOLS
            ):
                break
    finally:
        timer.cancel()
        if p.poll() is None:
            p.kill()
        p.wait()
    if not error and p.returncode not in (0, None, -9) and not skills and not others:
        err.seek(0)
        error = f"claude exit {p.returncode}: {err.read().strip()[:200]}"
    if not error and not events:
        error = f"the session printed nothing (claude exit {p.returncode})"
    if time.time() - t0 >= TIMEOUT and not skills:
        error = error or f"timed out after {TIMEOUT} s"
    err.close()
    bearing = [skill_name(s)[1] for s in skills if skill_name(s)[0] in PLUGIN_NAMES]
    return {
        "skills": skills,
        "first": bearing[0] if bearing else None,
        "other_tools": others,
        "tools": tools,
        "error": error,
        "seconds": round(time.time() - t0),
    }


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("--only", help="comma-separated skill names")
    ap.add_argument("--kind", choices=["should", "near"])
    ap.add_argument("-j", type=int, default=4, help="sessions at a time (default 4)")
    ap.add_argument("--model")
    ap.add_argument("--sources", default="project,local")
    ap.add_argument("--repeat", type=int, default=1)
    ap.add_argument("--min-recall", type=float, default=0.9)
    ap.add_argument("--max-false", type=float, default=0.1)
    ap.add_argument("--list", action="store_true")
    args = ap.parse_args()

    with open(CASES) as f:
        spec = json.load(f)
    only = set(args.only.split(",")) if args.only else None
    cases = []
    for entry in spec:
        if only and entry["skill"] not in only:
            continue
        for prompt in entry["should"]:
            cases.append(
                {
                    "skill": entry["skill"],
                    "kind": "should",
                    "prompt": prompt,
                    "expect": entry["skill"],
                }
            )
        for n in entry["near"]:
            cases.append(
                {
                    "skill": entry["skill"],
                    "kind": "near",
                    "prompt": n["prompt"],
                    "expect": n["expect"],
                }
            )
    if args.kind:
        cases = [c for c in cases if c["kind"] == args.kind]
    cases = [dict(c, repeat=r + 1) for c in cases for r in range(args.repeat)]
    if args.list:
        for c in cases:
            print(f"{c['skill']}\t{c['kind']}\t{c['prompt']}")
        print(f"trigger-eval: {len(cases)} cases listed")
        return 0 if cases else 1
    if not cases:
        print("trigger-eval: 0 cases selected; nothing checked", file=sys.stderr)
        return 1

    base = os.environ.get(
        "BRG_TRIGGER_EVAL_OUT", os.path.join(KIT, ".scratch", "trigger-eval")
    )
    os.makedirs(base, exist_ok=True)
    out = tempfile.mkdtemp(prefix=time.strftime("%Y%m%d-%H%M%S-"), dir=base)
    with tempfile.TemporaryDirectory(prefix="brg-trigger-") as root:
        cwd = build_fixture(root)
        done = [0]
        lock = threading.Lock()

        def one(c):
            r = dict(c, **run_case(cwd, c["prompt"], args))
            if r["error"]:
                r["status"] = "error"
            elif c["kind"] == "should":
                r["status"] = "pass" if r["first"] == c["skill"] else "fail"
            else:
                r["status"] = (
                    "fail"
                    if c["skill"] in [skill_name(s)[1] for s in r["skills"]]
                    else "pass"
                )
            with lock:
                done[0] += 1
                print(
                    f"[{done[0]}/{len(cases)}] {r['status']:5} {c['kind']:6} {c['skill']}: loaded {r['first'] or 'none'}",
                    flush=True,
                )
            return r

        with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.j)) as pool:
            results = list(pool.map(one, cases))

    with open(os.path.join(out, "results.json"), "w") as f:
        json.dump(
            {"sources": args.sources, "model": args.model, "results": results},
            f,
            indent=1,
        )

    by_skill = {}
    for r in results:
        by_skill.setdefault(r["skill"], []).append(r)
    print()
    for skill, rs in by_skill.items():
        should = [r for r in rs if r["kind"] == "should"]
        near = [r for r in rs if r["kind"] == "near"]
        wrong = sorted({r["first"] or "none" for r in should if r["status"] == "fail"})
        print(
            f"  {skill}: loaded on {sum(r['status'] == 'pass' for r in should)}/{len(should)}"
            f", false triggers {sum(r['status'] == 'fail' for r in near)}/{len(near)}"
            + (f"; instead: {', '.join(wrong)}" if wrong else "")
        )
    should = [r for r in results if r["kind"] == "should" and r["status"] != "error"]
    near = [r for r in results if r["kind"] == "near" and r["status"] != "error"]
    errors = [r for r in results if r["status"] == "error"]
    recall = sum(r["status"] == "pass" for r in should) / len(should) if should else 0.0
    false = sum(r["status"] == "fail" for r in near) / len(near) if near else 0.0
    sibling = [r for r in near if r["expect"]]
    sibling_hit = sum(r["first"] == r["expect"] for r in sibling)
    print(
        f"trigger-eval: {len(results)} cases over {len(by_skill)} skills, {len(errors)} errored; "
        f"recall {recall:.0%} ({sum(r['status'] == 'pass' for r in should)}/{len(should)}), "
        f"false triggers {false:.0%} ({sum(r['status'] == 'fail' for r in near)}/{len(near)}), "
        f"near misses routed to the expected sibling {sibling_hit}/{len(sibling)}; "
        f"sources {args.sources}; results in {os.path.relpath(out, KIT)}/results.json"
    )
    if errors:
        print(f"first error: {errors[0]['error']}", file=sys.stderr)
    ok = (
        bool(should)
        and not errors
        and recall >= args.min_recall
        and false <= args.max_false
    )
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
