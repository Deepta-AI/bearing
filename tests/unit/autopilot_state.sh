#!/usr/bin/env bash
# tests/unit/autopilot_state.sh: plugins/bearing/bin/brg-autopilot keeps the order and checks
# every gate on disk. A new run starts at repo; done on a stage whose gate is
# not met fails and says what is missing; stages run in order; an ADR this
# run wrote as Accepted fails the decide gate; three failed attempts block a
# stage; an upstream on the branch fails the mr gate (the run never pushes);
# the report carries the digest; a second start on an open run is refused.
set -u
. "$(dirname "$0")/../lib/assert.sh"
AP="$KIT/plugins/bearing/bin/brg-autopilot"; export AP
d="$(tmpdir)/run"
ap() { python3 "$AP" "$@" --dir "$d"; }
commit() { git -C "$d" add -A >/dev/null 2>&1; git -C "$d" -c user.email=t@e -c user.name=t commit -qm "$1" >/dev/null 2>&1; }

t_begin "a run starts at the repo stage and refuses a second start"
assert_exit 0 ap start "a word counter"
assert_contains "$T_OUT" "15 stages"
assert_contains "$T_OUT" "next: repo"
assert_exit 1 ap start "another"
assert_contains "$T_OUT" "is open at stage repo"
t_end

t_begin "the repo gate checks git and a check target that records a pass"
assert_exit 1 ap "done" repo
assert_contains "$T_OUT" "not a git repository"
git -C "$d" init -q -b main
printf 'check:\n\t@true\n' > "$d/Makefile"
assert_exit 1 ap "done" repo
assert_contains "$T_OUT" "does not record a pass"
printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"
printf '.bearing/state/\n.scratch/\n' > "$d/.gitignore"; commit init
assert_exit 0 ap "done" repo
assert_contains "$T_OUT" "gate repo: passed"
assert_contains "$T_OUT" "next: prd"
t_end

t_begin "stages run in order; prd and stories gates count what is on disk"
assert_exit 1 ap "done" stories
assert_contains "$T_OUT" "the next stage is prd, not stories"
mkdir -p "$d/docs/product"; printf '# PRD\nNo statements yet.\n' > "$d/docs/product/PRD.md"
assert_exit 1 ap "done" prd
assert_contains "$T_OUT" "0 REQ statements"
printf '# PRD\nREQ-001 count words.\nREQ-002 print the top N.\n' > "$d/docs/product/PRD.md"
assert_exit 0 ap "done" prd
assert_contains "$T_OUT" "2 REQ statements"
printf '# Backlog\nUS-01-001 count\n- AC-US-01-001-1 ok\n- AC-US-01-001-2 ok\n' > "$d/docs/product/backlog.md"
assert_exit 1 ap "done" stories
assert_contains "$T_OUT" "backlog: 1 stories; coverage.md: missing"
printf '# Coverage\n' > "$d/docs/product/coverage.md"
assert_exit 0 ap "done" stories
t_end

t_begin "the decide gate needs a digest and refuses an Accepted ADR"
assert_exit 1 ap "done" decide
assert_contains "$T_OUT" "0 decisions in the digest"
assert_exit 0 ap decision language Python "Go, Node" "stdlib only, no build step"
mkdir -p "$d/docs/adr"; printf '# 1. Use Python\n\nStatus: Accepted\n' > "$d/docs/adr/0001-python.md"
assert_exit 1 ap "done" decide
assert_contains "$T_OUT" "say Accepted"
printf '# 1. Use Python\n\nStatus: Proposed\n' > "$d/docs/adr/0001-python.md"
assert_exit 1 ap "done" decide
assert_contains "$T_OUT" "no product profile"
assert_exit 0 ap profile --ui no --data no --api no --deploy no --why "a command-line tool"
assert_exit 0 ap "done" decide
assert_contains "$T_OUT" "2 decisions in the digest, none recorded as Accepted; profile: ui=no data=no api=no deploy=no"
t_end

t_begin "three failed attempts block a stage and the run stops there"
assert_exit 0 ap fail architecture "no C4 yet"
assert_exit 0 ap fail architecture "still none"
assert_exit 1 ap fail architecture "gave up"
assert_contains "$T_OUT" "blocked"
assert_exit 1 ap next
assert_contains "$T_OUT" "blocked after 3 attempts"
t_end

t_begin "the report carries the digest, the stages and the failed attempts"
assert_exit 0 ap report
run="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["run"])' "$d/.bearing/state/autopilot.json")"
rep="$(cat "$d/docs/autopilot/$run.md")"
assert_contains "$rep" "| language | Python | Go, Node | stdlib only, no build step |"
assert_contains "$rep" "| architecture | blocked | 3 |"
assert_contains "$rep" "- architecture: gave up"
assert_contains "$rep" "Nothing was pushed, merged or deployed."
t_end

t_begin "sandbox placeholders and the run's report are not uncommitted work"
d3="$(tmpdir)/run3"; d_keep="$d"; d="$d3"
git init -q -b main "$d"; printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"
printf '.bearing/state/\n' > "$d/.gitignore"; commit init
git -C "$d" checkout -q -b feature/T-2-y; printf 'x\n' > "$d/tool.txt"; mkdir -p "$d/web"; printf 'w\n' > "$d/web/app.txt"; commit feat
( cd "$d" && make -s check )
mkdir -p "$d/.bearing/state"
python3 - "$d/.bearing/state/autopilot.json" <<'PY'
import json, sys, time
import os, subprocess
names = subprocess.check_output(["python3", os.environ["AP"], "stages"], text=True).split()
st = {"run": "r", "statement": "s", "started": "t", "started_epoch": time.time(), "decisions": [],
      "stages": {n: {"status": "done" if n not in ("dod", "mr") else "pending", "attempts": 0, "checked": "", "notes": []} for n in names}}
json.dump(st, open(sys.argv[1], "w"))
PY
: > "$d/.mcp.json"; : > "$d/.bashrc"; mkdir -p "$d/.idea" "$d/docs/autopilot"; printf 'report\n' > "$d/docs/autopilot/r.md"
# The sandbox holds them in whichever directory a command runs, not only the root
: > "$d/web/.mcp.json"; mkdir -p "$d/web/.claude/.cc-writes"; : > "$d/web/.claude/hooks"; : > "$d/web/.claude/launch.json"
assert_exit 0 ap "done" dod
assert_contains "$T_OUT" "gate dod: passed"
d="$d_keep"
t_end

# A real run reached a prepared MR with a sign-in that could never
# work: every gate was make check, and nothing ever ran the shipped app. A
# repository that ships something runnable must show a smoke run of it.
t_begin "a runnable repository needs a passing smoke run newer than its last commit"
d5="$(tmpdir)/run5"; d_keep="$d"; d="$d5"
git init -q -b main "$d"; printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"
printf '.bearing/state/\n.scratch/\n' > "$d/.gitignore"; commit init
git -C "$d" checkout -q -b feature/T-5-app
printf 'services:\n  web:\n    image: nginx\n' > "$d/docker-compose.yml"; commit feat
( cd "$d" && make -s check )
mkdir -p "$d/.bearing/state"
python3 - "$d/.bearing/state/autopilot.json" <<'PY'
import json, sys, time
import os, subprocess
names = subprocess.check_output(["python3", os.environ["AP"], "stages"], text=True).split()
st = {"run": "r", "statement": "s", "started": "t", "started_epoch": time.time(), "decisions": [],
      "stages": {n: {"status": "done" if n not in ("dod", "mr") else "pending", "attempts": 0, "checked": "", "notes": []} for n in names}}
json.dump(st, open(sys.argv[1], "w"))
PY
assert_exit 1 ap "done" dod
assert_contains "$T_OUT" "the app was never run: no .scratch/smoke-*.md"
mkdir -p "$d/.scratch"
printf 'smoke: 0 requests checked, 0 failed\n' > "$d/.scratch/smoke-T-5.md"
assert_exit 1 ap "done" dod
assert_contains "$T_OUT" "smoke checked 0 requests"
printf 'smoke: 12 requests checked, 1 failed\n' > "$d/.scratch/smoke-T-5.md"
assert_exit 1 ap "done" dod
assert_contains "$T_OUT" "smoke: 1 of 12 requests failed"
printf 'smoke: 12 requests checked, 0 failed\n' > "$d/.scratch/smoke-T-5.md"
touch -t 200101010000 "$d/.scratch/smoke-T-5.md"
assert_exit 1 ap "done" dod
assert_contains "$T_OUT" "the smoke run is older than the last commit"
touch "$d/.scratch/smoke-T-5.md"
assert_exit 0 ap "done" dod
assert_contains "$T_OUT" "smoke: 12 requests checked, 0 failed"
d="$d_keep"
t_end

t_begin "a repository with nothing to run passes dod without a smoke run"
d6="$(tmpdir)/run6"; d_keep="$d"; d="$d6"
git init -q -b main "$d"; printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"
printf '.bearing/state/\n' > "$d/.gitignore"; commit init
git -C "$d" checkout -q -b feature/T-6-lib; printf 'x\n' > "$d/lib.txt"; commit feat
( cd "$d" && make -s check )
mkdir -p "$d/.bearing/state"
python3 - "$d/.bearing/state/autopilot.json" <<'PY'
import json, sys, time
import os, subprocess
names = subprocess.check_output(["python3", os.environ["AP"], "stages"], text=True).split()
st = {"run": "r", "statement": "s", "started": "t", "started_epoch": time.time(), "decisions": [],
      "stages": {n: {"status": "done" if n not in ("dod", "mr") else "pending", "attempts": 0, "checked": "", "notes": []} for n in names}}
json.dump(st, open(sys.argv[1], "w"))
PY
assert_exit 0 ap "done" dod
assert_contains "$T_OUT" "nothing to run (no compose file, Dockerfile or make dev/up target)"
d="$d_keep"
t_end

t_begin "a real change named like a placeholder still counts"
d4="$(tmpdir)/run4"; d_keep="$d"; d="$d4"
git init -q -b main "$d"; printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"
printf '.bearing/state/\n' > "$d/.gitignore"; commit init
git -C "$d" checkout -q -b feature/T-3-z; printf 'x\n' > "$d/tool.txt"; mkdir -p "$d/web"; printf 'w\n' > "$d/web/app.txt"; commit feat
mkdir -p "$d/.bearing/state"
python3 - "$d/.bearing/state/autopilot.json" <<'PY'
import json, sys, time
import os, subprocess
names = subprocess.check_output(["python3", os.environ["AP"], "stages"], text=True).split()
st = {"run": "r", "statement": "s", "started": "t", "started_epoch": time.time(), "decisions": [],
      "stages": {n: {"status": "done" if n not in ("dod", "mr") else "pending", "attempts": 0, "checked": "", "notes": []} for n in names}}
json.dump(st, open(sys.argv[1], "w"))
PY
printf '{"mcpServers":{}}\n' > "$d/.mcp.json"; printf '{"mcpServers":{}}\n' > "$d/web/.mcp.json"
( cd "$d" && make -s check )
assert_exit 1 ap "done" dod
assert_contains "$T_OUT" "2 uncommitted change(s)"
d="$d_keep"
t_end

t_begin "the mr gate refuses a branch that has an upstream"
d2="$(tmpdir)/run2"; d_save="$d"; d="$d2"
git init -q -b main "$d"; printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"; commit init
bare="$(tmpdir)/remote.git"; git init -q --bare "$bare"; git -C "$d" remote add origin "$bare"
git -C "$d" checkout -q -b feature/T-1-x; git -C "$d" push -q -u origin feature/T-1-x 2>/dev/null
python3 - "$d/.bearing/state/autopilot.json" <<'PY'
import json, sys, time
p = sys.argv[1]
import os; os.makedirs(os.path.dirname(p), exist_ok=True)
import os, subprocess
names = subprocess.check_output(["python3", os.environ["AP"], "stages"], text=True).split()
st = {"run": "r", "statement": "s", "started": "t", "started_epoch": time.time(), "decisions": [],
      "stages": {n: {"status": "done" if n != "mr" else "pending", "attempts": 0, "checked": "", "notes": []} for n in names}}
json.dump(st, open(p, "w"))
PY
assert_exit 1 ap "done" mr
assert_contains "$T_OUT" "the run must not push"
d="$d_save"
t_end

# A run on a branch the engineer had already pushed (a backfill) was refused at mr for an upstream it never touched. The start
# records where the upstream stood; only a move during the run fails.
t_begin "the mr gate accepts an upstream the engineer pushed before the run, and refuses a push during it"
d7="$(tmpdir)/run7"; d_save="$d"; d="$d7"
git init -q -b main "$d"; printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"; commit init
bare="$(tmpdir)/remote7.git"; git init -q --bare "$bare"; git -C "$d" remote add origin "$bare"
git -C "$d" checkout -q -b feature/T-7-x; git -C "$d" push -q -u origin feature/T-7-x 2>/dev/null
assert_exit 0 ap start "backfill a pushed branch"
python3 - "$d/.bearing/state/autopilot.json" <<'PY'
import json, sys
p = sys.argv[1]; st = json.load(open(p))
for n in st["stages"]:
    if n != "mr":
        st["stages"][n]["status"] = "done"
json.dump(st, open(p, "w"))
PY
mkdir -p "$d/.scratch" "$d/docs/autopilot"; printf 'mr\n' > "$d/.scratch/mr-T-7.md"
run="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["run"])' "$d/.bearing/state/autopilot.json")"
printf 'report\n' > "$d/docs/autopilot/$run.md"; commit report
assert_exit 0 ap "done" mr
assert_contains "$T_OUT" "upstream origin/feature/T-7-x unchanged since the run started"
python3 - "$d/.bearing/state/autopilot.json" <<'PY'
import json, sys
p = sys.argv[1]; st = json.load(open(p)); st["stages"]["mr"]["status"] = "pending"; json.dump(st, open(p, "w"))
PY
git -C "$d" push -q 2>/dev/null
assert_exit 1 ap "done" mr
assert_contains "$T_OUT" "was pushed during the run"
d="$d_save"
t_end

t_summary
