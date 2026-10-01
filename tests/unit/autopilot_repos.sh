#!/usr/bin/env bash
# tests/unit/autopilot_repos.sh: the repos stage scaffolds every repository in
# docs/architecture/repo-plan.json beside the run's own repository. The run
# repository is the product's home (its PRD, ADRs and designs); an entry named
# like it is that repository and is not created again. The gate fails on an
# empty plan, a missing sibling and one whose make check never passed. A
# headless run cannot write outside its directory, so it asks the launcher
# (brg-autopilot repos-request), which runs brg-scaffold outside the sandbox
# and resumes the session with what it made.
set -u
. "$(dirname "$0")/../lib/assert.sh"
AP="$KIT/plugins/bearing/bin/brg-autopilot"; export AP
ap() { python3 "$AP" "$@" --dir "$d"; }
commit() { git -C "$1" add -A >/dev/null 2>&1; git -C "$1" -c user.email=t@e -c user.name=t commit -qm "$2" >/dev/null 2>&1; }

# at_repos: a repository shop-api in a fresh workspace whose run has every
# stage before repos done, profile full.
at_repos() {
  ws="$(tmpdir)"; d="$ws/shop-api"
  git init -q -b main "$d"
  printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"
  printf '.bearing/state/\n.scratch/\n.fake-*\n' > "$d/.gitignore"; commit "$d" init
  mkdir -p "$d/.bearing/state"
  python3 - "$d/.bearing/state/autopilot.json" "$(python3 "$AP" stages)" <<'PY'
import json, sys, time
path, names = sys.argv[1], sys.argv[2].split()
st = {"run": "r", "statement": "s", "started": "t", "started_epoch": time.time(), "decisions": [],
      "stages": {n: {"status": "done" if names.index(n) < names.index("repos") else "pending",
                     "attempts": 0, "checked": "", "notes": []} for n in names}}
json.dump(st, open(path, "w"))
PY
  ap profile --ui yes --data yes --api yes --deploy no --why fixture >/dev/null
}
# plan <entries json>: write the repo plan.
plan() {
  mkdir -p "$d/docs/architecture"
  printf '{"project": "Shop", "group": "Shop", "repos": [%s]}\n' "$1" > "$d/docs/architecture/repo-plan.json"
}
API='{"name": "ShopApi", "git_path": "Shop/Server/ShopApi", "stack": "go-api", "responsibility": "orders"}'
WEB='{"name": "ShopClient", "git_path": "Shop/Client/ShopClient", "stack": "react-web", "responsibility": "screens"}'
INFRA='{"name": "ShopInfra", "git_path": "Shop/Infrastructure/ShopInfra", "stack": "infra", "responsibility": "envs"}'
# sibling <Name> [passed]: a scaffolded repository beside the run; passed
# records a make check pass.
sibling() {
  local s="$ws/$1"
  git init -q -b main "$s"
  printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$s/Makefile"
  [ "${2:-}" = passed ] && mkdir -p "$s/.bearing/state" && touch "$s/.bearing/state/.check-passed"
  return 0
}

t_begin "the repos stage runs after design and before ux"
assert_exit 0 python3 "$AP" stages
assert_contains "$(printf '%s' "$T_OUT" | tr '\n' ' ')" "design repos ux" "stage order"
t_end

t_begin "lean scope has no repo plan: this repository is the only one"
at_repos; ap profile --ui no --data no --api no --deploy no --why fixture >/dev/null
assert_exit 0 ap "done" repos
assert_contains "$T_OUT" "scope lean"
assert_contains "$T_OUT" "this repository is the only one"
t_end

t_begin "full scope fails without a repo plan and on an empty one"
at_repos
assert_exit 1 ap "done" repos
assert_contains "$T_OUT" "no docs/architecture/repo-plan.json (high-level-design)"
plan ""
assert_exit 1 ap "done" repos
assert_contains "$T_OUT" "0 repos"
printf 'not json' > "$d/docs/architecture/repo-plan.json"
assert_exit 1 ap "done" repos
assert_contains "$T_OUT" "does not parse"
t_end

t_begin "every entry but the run's own repository must exist beside it, scaffolded and checked"
at_repos; plan "$API, $WEB, $INFRA"
assert_exit 1 ap "done" repos
assert_contains "$T_OUT" "3 repos in the plan"
assert_contains "$T_OUT" "ShopClient: missing"
assert_contains "$T_OUT" "ShopInfra: missing"
assert_not_contains "$T_OUT" "ShopApi: missing" "the run repository"
assert_contains "$T_OUT" "new-repo react-web ShopClient --dir $ws/ShopClient"
assert_contains "$T_OUT" "brg-autopilot repos-request"
sibling ShopClient passed; sibling ShopInfra
assert_exit 1 ap "done" repos
assert_contains "$T_OUT" "ShopInfra: make check has never passed"
assert_not_contains "$T_OUT" "ShopClient:" "a ready sibling"
touch "$ws/ShopInfra/.bearing/state/.check-passed" 2>/dev/null || { mkdir -p "$ws/ShopInfra/.bearing/state"; touch "$ws/ShopInfra/.bearing/state/.check-passed"; }
assert_exit 0 ap "done" repos
assert_contains "$T_OUT" "3 repos in the plan: ShopApi is this repository; ShopClient, ShopInfra scaffolded beside it, make check passed in each"
t_end

t_begin "a sibling that is not a repository on the standard fails the gate"
at_repos; plan "$WEB"
mkdir -p "$ws/ShopClient"; printf 'hello\n' > "$ws/ShopClient/README.md"
assert_exit 1 ap "done" repos
assert_contains "$T_OUT" "ShopClient: not a git repository"
t_end

t_begin "a plan of one repository says so in the singular"
at_repos; plan "$WEB"; sibling ShopClient passed
assert_exit 0 ap "done" repos
assert_contains "$T_OUT" "1 repo in the plan: ShopClient scaffolded beside it"
t_end

t_begin "the report lists the repositories the run scaffolded"
at_repos; plan "$API, $WEB"; sibling ShopClient passed
assert_exit 0 ap "done" repos
assert_contains "$T_OUT" "2 repos in the plan: ShopApi is this repository; ShopClient scaffolded beside it"
assert_exit 0 ap report
rep="$(cat "$d/docs/autopilot/r.md")"
assert_contains "$rep" "## Repositories"
assert_contains "$rep" "| ShopApi | go-api | this repository |"
assert_contains "$rep" "| ShopClient | react-web | $ws/ShopClient |"
t_end

t_begin "repos-request asks for the missing entries only, and refuses when nothing is missing"
at_repos; plan "$API, $WEB, $INFRA"; sibling ShopInfra passed
assert_exit 0 ap repos-request
assert_contains "$T_OUT" "1 repo to scaffold outside the sandbox: ShopClient"
assert_contains "$T_OUT" "end your turn"
assert_contains "$(cat "$d/.bearing/state/autopilot.json")" '"pending": true'
plan "$API"
assert_exit 1 ap repos-request
assert_contains "$T_OUT" "0 repos to scaffold"
t_end

# The fake claude asks for the repos on its first call; the fake scaffold
# records its argv, makes the repository and passes its check.
fake="$(tmpdir)/claude"
cat > "$fake" <<'SH'
#!/usr/bin/env bash
n=$(cat .fake-calls 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > .fake-calls
printf '%s\n' "$@" > ".fake-argv-$n"
printf '{"type":"system","subtype":"init","session_id":"sess-r","tools":[]}\n'
[ "$n" -eq 1 ] && python3 "$AP" repos-request --dir "$PWD"
printf '{"type":"result","subtype":"success"}\n'
SH
scaffold="$(tmpdir)/brg-scaffold"
cat > "$scaffold" <<'SH'
#!/usr/bin/env bash
echo "$*" >> "$FAKE_LOG"
dir=""; while [ $# -gt 0 ]; do [ "$1" = --dir ] && dir="$2"; shift; done
git init -q -b main "$dir"
printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$dir/Makefile"
mkdir -p "$dir/.bearing/state"; touch "$dir/.bearing/state/.check-passed"
echo "brg-scaffold: 9 files written to $dir"
SH
chmod +x "$fake" "$scaffold"
export BRG_CLAUDE="$fake" BRG_SCAFFOLD="$scaffold"

t_begin "launch scaffolds the requested repos outside the sandbox and resumes the session"
at_repos; plan "$API, $WEB, $INFRA"
export FAKE_LOG="$ws/scaffold.log"
assert_exit 0 bash -c "cd '$d' && python3 '$AP' launch 'a shop' --dir '$d'"
assert_contains "$T_OUT" "scaffolding 2 repos outside the sandbox"
assert_contains "$(cat "$FAKE_LOG")" "react-web ShopClient --dir $ws/ShopClient --check"
assert_contains "$(cat "$FAKE_LOG")" "infra ShopInfra --dir $ws/ShopInfra --check"
assert_eq "2" "$(wc -l < "$FAKE_LOG" | tr -d ' ')" "scaffold runs"
argv2="$(cat "$d/.fake-argv-2")"
assert_contains "$argv2" "sess-r"
assert_contains "$argv2" "ShopClient, ShopInfra"
assert_contains "$argv2" "brg-autopilot done repos"
assert_not_contains "$(cat "$d/.bearing/state/autopilot.json")" '"pending": true' "state after scaffolding"
assert_exit 0 ap "done" repos
t_end

t_summary
