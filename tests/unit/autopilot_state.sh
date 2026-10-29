#!/usr/bin/env bash
# tests/unit/autopilot_state.sh: plugins/bearing/bin/brg-autopilot keeps the order and checks
# every gate on disk. A new run starts at repo; done on a stage whose gate is
# not met fails and says what is missing; stages run in order; an ADR this
# run wrote as Accepted fails the decide gate; three failed attempts block a
# stage; an upstream on the branch fails the mr gate unless brg-push pushed it at HEAD (the run never pushes itself);
# the report carries the digest; a second start on an open run is refused.
set -u
. "$(dirname "$0")/../lib/assert.sh"
# the trust check reads $HOME/.claude.json; a test never reads the real one
HOME="$(tmpdir)"; export HOME
AP="$KIT/plugins/bearing/bin/brg-autopilot"; export AP
d="$(tmpdir)/run"
ap() { python3 "$AP" "$@" --dir "$d"; }
commit() { git -C "$d" add -A >/dev/null 2>&1; git -C "$d" -c user.email=t@e -c user.name=t commit -qm "$1" >/dev/null 2>&1; }
# fullrun: definition-of-done item 14's passing full-run evidence for HEAD
# (runners.md schema), dated in the past so it is never newer than make check.
fullrun() {
  local f
  f="$d/.scratch/test-run/$(git -C "$d" branch --show-current | tr / _)-full.json"
  mkdir -p "$d/.scratch/test-run"
  printf '{"scope": "full", "sha": "%s", "dirty": false, "base": "", "files": null, "layers": [], "except": ["unit"], "suites": [{"name": "e2e", "status": "run", "reason": "", "passed": 2, "failed": 0, "skipped": 0}], "tests": 2, "failed": 0, "not_run": [], "failures": [], "selection": {"except": ["unit"]}}\n' \
    "$(git -C "$d" rev-parse HEAD)" > "$f"
  touch -t 200101010000 "$f"
}

t_begin "start refuses an untrusted workspace and names the allow entries it would ignore"
ud="$(tmpdir)/untrusted"; mkdir -p "$ud/.claude"; git init -q -b main "$ud"
printf '{"permissions":{"allow":["Bash(make:*)"]}}\n' > "$ud/.claude/settings.json"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":false}}}\n' "$(git -C "$ud" rev-parse --show-toplevel)" > "$HOME/.claude.json"
assert_exit 1 python3 "$AP" start "a word counter" --dir "$ud"
assert_contains "$T_OUT" "workspace not trusted; 1 allow entries"
assert_exit 0 test ! -f "$ud/.bearing/state/autopilot.json"
rm -f "$HOME/.claude.json"
t_end

t_begin "start proceeds in an untrusted workspace that has no allow entries"
zd="$(tmpdir)/zero"; git init -q -b main "$zd"
printf '{"projects":{"%s":{"hasTrustDialogAccepted":false}}}\n' "$(git -C "$zd" rev-parse --show-toplevel)" > "$HOME/.claude.json"
assert_exit 0 python3 "$AP" start "a word counter" --dir "$zd"
rm -f "$HOME/.claude.json"
t_end

t_begin "a run starts at the repo stage and refuses a second start"
assert_exit 0 ap start "a word counter"
assert_contains "$T_OUT" "$(python3 "$AP" stages | wc -l | tr -d ' ') stages"
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
assert_contains "$T_OUT" "next: branch"
t_end

t_begin "a run started before a stage existed gets that stage as pending"
python3 - "$d/.bearing/state/autopilot.json" <<'PY'
import json, sys
st = json.load(open(sys.argv[1])); del st["stages"]["lld"]; json.dump(st, open(sys.argv[1], "w"))
PY
assert_exit 0 ap status
assert_contains "$T_OUT" "lld"
t_end

t_begin "the branch comes before any document, so no stage commits on the trunk"
assert_exit 1 ap "done" branch
assert_contains "$T_OUT" "branch: main"
git -C "$d" checkout -q -b feature/T-1-WordCounter
assert_exit 0 ap "done" branch
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
assert_contains "$rep" "Nothing was merged or deployed; the push is the engineer's, or brg-push's where"
t_end

t_begin "sandbox placeholders and the run's report are not uncommitted work"
d3="$(tmpdir)/run3"; d_keep="$d"; d="$d3"
git init -q -b main "$d"; printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"
printf '.bearing/state/\n' > "$d/.gitignore"; commit init
git -C "$d" checkout -q -b feature/T-2-y; printf 'x\n' > "$d/tool.txt"; mkdir -p "$d/web"; printf 'w\n' > "$d/web/app.txt"; commit feat
( cd "$d" && make -s check ); fullrun
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
( cd "$d" && make -s check ); fullrun
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
( cd "$d" && make -s check ); fullrun
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
fullrun; mkdir -p "$d/.bearing/state"
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

# The opt-in push (brg-push, from the Stop hook) is the one push a run may cause. Its clone sets no upstream, so this
# path fires only after a fetch; any other upstream at HEAD still fails.
t_begin "the mr gate accepts an upstream brg-push pushed at HEAD, and nothing else"
d8="$(tmpdir)/run8"; d_save="$d"; d="$d8"
git init -q -b main "$d"; printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"; commit init
bare="$(tmpdir)/remote8.git"; git init -q --bare "$bare"; git -C "$d" remote add origin "$bare"
git -C "$d" checkout -q -b feature/T-8-x
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
mkdir -p "$d/.scratch" "$d/docs/autopilot"; printf 'mr\n' > "$d/.scratch/mr-T-8.md"; printf 'r\n' > "$d/docs/autopilot/r.md"; git -C "$d" add docs; commit report
git -C "$d" push -q -u origin feature/T-8-x 2>/dev/null
printf 'pushed feature/T-8-x %s to git.example.test/group/shop 2026-10-18T10:00:00Z\n' "$(git -C "$d" rev-parse HEAD)" > "$d/.bearing/state/push-result"
assert_exit 0 ap "done" mr
assert_contains "$T_OUT" "pushed by brg-push"
python3 - "$d/.bearing/state/autopilot.json" <<'PY'
import json, sys
p = sys.argv[1]; st = json.load(open(p)); st["stages"]["mr"]["status"] = "pending"; json.dump(st, open(p, "w"))
PY
printf 'pushed feature/T-8-x %s to git.example.test/group/shop 2026-10-18T10:00:00Z\n' "0000000000000000000000000000000000000000" > "$d/.bearing/state/push-result"
assert_exit 1 ap "done" mr
assert_contains "$T_OUT" "the run must not push"
printf 'push failed: remote refused\n' > "$d/.bearing/state/push-result"
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

# oldrun <state file> <last done stage>: a run written by the 17-stage
# brg-autopilot (no contract stage), done up to and including the stage named.
oldrun() {
  python3 -c '
import json, sys
old = "repo branch prd stories decide architecture design repos ux lld test_cases build test_automation design_review review dod mr".split()
st = {"run": "r", "statement": "s", "started": "t", "started_epoch": 0, "decisions": [],
      "stages": {n: {"status": "done" if old.index(n) <= old.index(sys.argv[2]) else "pending",
                     "attempts": 0, "checked": "", "notes": []} for n in old}}
json.dump(st, open(sys.argv[1], "w"))
' "$1" "$2"
}

t_begin "a run from before the contract stage, past ux, carries contract from its old design gate"
od="$(tmpdir)/old-run"; mkdir -p "$od/.bearing/state"
oldrun "$od/.bearing/state/autopilot.json" lld
assert_exit 0 python3 "$AP" next --dir "$od"
assert_contains "$T_OUT" "next: test_cases"
assert_contains "$T_OUT" "contract carried from the old design gate"
assert_exit 0 python3 "$AP" status --dir "$od"
assert_contains "$T_OUT" "carried from the old design gate"
# a run not yet past ux runs the new contract gate in its turn
oldrun "$od/.bearing/state/autopilot.json" design
assert_exit 0 python3 "$AP" next --dir "$od"
assert_contains "$T_OUT" "next: repos"
assert_not_contains "$T_OUT" "carried"
t_end

t_begin "a run from before the test_run stage, past a stage after it, is not pulled back to it"
od="$(tmpdir)/old-run2"; mkdir -p "$od/.bearing/state"
oldrun "$od/.bearing/state/autopilot.json" design_review
assert_exit 0 python3 "$AP" next --dir "$od"
assert_contains "$T_OUT" "next: review"
assert_contains "$T_OUT" "test_run carried: the run was past test_automation"
# a run that stopped right after test_automation runs the new test_run gate next
oldrun "$od/.bearing/state/autopilot.json" test_automation
assert_exit 0 python3 "$AP" next --dir "$od"
assert_contains "$T_OUT" "next: test_run"
assert_not_contains "$T_OUT" "test_run carried"
# a run not yet past test_automation runs the new test_run gate in its turn
oldrun "$od/.bearing/state/autopilot.json" build
assert_exit 0 python3 "$AP" next --dir "$od"
assert_contains "$T_OUT" "next: test_automation"
assert_not_contains "$T_OUT" "test_run carried"
t_end

t_begin "a planning run (--until design) covers the planning stages and stops there"
pd="$(tmpdir)/plan"; git init -q -b main "$pd"
assert_exit 0 python3 "$AP" start "a clinic booking service from my notes" --until design --dir "$pd"
assert_contains "$T_OUT" "7 of 19 stages, until design"
assert_contains "$T_OUT" "next: repo"
python3 - "$pd/.bearing/state/autopilot.json" <<'PY'
import json, sys
st = json.load(open(sys.argv[1]))
for n in ("repo", "branch", "prd", "stories", "decide", "architecture", "design"):
    st["stages"][n]["status"] = "done"
json.dump(st, open(sys.argv[1], "w"))
PY
assert_exit 0 python3 "$AP" next --dir "$pd"
assert_contains "$T_OUT" "planning done through design; not run: repos, ux,"
assert_contains "$T_OUT" "start-task on the first story"
assert_exit 0 python3 "$AP" report --dir "$pd"
r="$(ls "$pd"/docs/autopilot/*.md)"
assert_contains "$(cat "$r")" "- build: not run (planning run, until design)"
assert_not_contains "$(cat "$r")" "- design:" "a done planning stage is not under Not done"
assert_exit 0 python3 "$AP" decision db postgres "sqlite" "the notes name it" --dir "$pd"
assert_exit 0 python3 "$AP" continue --dir "$pd"
assert_contains "$T_OUT" "continues past design, 1 decisions kept"
assert_contains "$T_OUT" "next: repos"
assert_exit 1 python3 "$AP" continue --dir "$pd"
assert_contains "$T_OUT" "not a planning run"
t_end

t_begin "--until takes a planning stage only"
assert_exit 2 python3 "$AP" start "x" --until nowhere --dir "$(tmpdir)"
assert_exit 2 python3 "$AP" start "x" --until test_run --dir "$(tmpdir)"
assert_contains "$T_OUT" "invalid choice" "a build stage is not a planning stop"
t_end

t_summary
