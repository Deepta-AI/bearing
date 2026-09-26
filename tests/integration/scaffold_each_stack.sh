#!/usr/bin/env bash
# tests/integration/scaffold_each_stack.sh: bin/brg-scaffold for every stack
# id found in skills/*/templates*/stack.json. Each scaffold runs with a
# PATH that holds git, python3, make and coreutils but no stack toolchain, so
# the install step is skipped deterministically (no network, no lockfile) and
# the assertions are about the templates: exit 0, no unfilled placeholders, a
# git repository with core.hooksPath=.githooks and executable hooks, CLAUDE.md
# importing AGENTS.md, a parsing .claude/settings.json, both hosts' CI and
# change templates under --host both, a Makefile whose check target make -n
# accepts. --host github and --host gitlab are checked on go-api. Then, for
# go-api and python-api, make check under that same tool-free PATH must fail:
# python-api reaches the tally and reports every gate skipped (and passes
# only with BEARING_ALLOW_SKIP=1); go-api fails closed at its first gate that
# finds zero packages. The full make check per stack is the CI scaffold job.
set -u
. "$(dirname "$0")/../lib/assert.sh"
SCAFFOLD="$KIT/bin/brg-scaffold"
TOOLFREE="$(minimal_path bash sh git python3 make sed grep find cut sort uniq wc tr mktemp mv cp rm mkdir chmod ls cat basename dirname head tail stat touch env date awk xargs cmp diff)"

# scaffold <stack> <Name> <dir> <host>: brg-scaffold under the tool-free PATH,
# with the developer's env file out of the picture.
scaffold() { env -u BEARING_TRACKER -u BEARING_GIT_HOST PATH="$TOOLFREE" BEARING_ENV=/nonexistent bash "$SCAFFOLD" "$1" "$2" --dir "$3" --host "$4"; }
# in_dir <dir> <cmd...>: run the command from inside the directory.
in_dir() { local d="$1"; shift; (cd "$d" && "$@"); }
json_ok() { python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" 2>/dev/null; }
assert_json() { _t_count; if json_ok "$1"; then :; else _t_fail "invalid JSON: $1"; fi; }
assert_exec() { _t_count; if [ -x "$1" ]; then :; else _t_fail "not executable: $1"; fi; }
assert_absent() { _t_count; if [ -e "$1" ]; then _t_fail "should not exist: $1"; fi; }
pascal() { printf '%s' "$1" | awk -F- '{for(i=1;i<=NF;i++) printf "%s%s", toupper(substr($i,1,1)), substr($i,2)}'; }

ids="$(grep -h '"id"' "$KIT"/skills/*/templates*/stack.json | sed -E 's/.*"id": *"([^"]+)".*/\1/' | sort)"
n=0
for id in $ids; do
  n=$((n+1))
  name="Probe$(pascal "$id")"
  repo="$(tmpdir)/probe-$id"
  t_begin "$id --host both"
  assert_exit 0 scaffold "$id" "$name" "$repo" both
  assert_contains "$T_OUT" "host: both (--host)"
  assert_contains "$T_OUT" "brg-scaffold: "
  assert_contains "$T_OUT" "(stack $id, host both, "
  assert_contains "$T_OUT" " 0 files with unfilled placeholders)"
  assert_not_contains "$T_OUT" "note: " "every host file set ships for $id"
  assert_file "$repo/.git/HEAD"
  assert_eq ".githooks" "$(git -C "$repo" config core.hooksPath)" "$id core.hooksPath"
  for h in commit-msg pre-commit pre-push install.sh; do assert_file "$repo/.githooks/$h"; assert_exec "$repo/.githooks/$h"; done
  assert_eq "@AGENTS.md" "$(head -1 "$repo/CLAUDE.md")" "$id CLAUDE.md first line"
  assert_file "$repo/AGENTS.md"
  assert_file "$repo/.claude/settings.json"; assert_json "$repo/.claude/settings.json"
  assert_file "$repo/.gitlab-ci.yml"
  assert_file "$repo/.github/workflows/ci.yml"
  assert_file "$repo/.gitlab/merge_request_templates/Default.md"
  assert_file "$repo/.github/PULL_REQUEST_TEMPLATE.md"
  assert_file "$repo/Makefile"
  assert_eq 1 "$(grep -Eq '^check:' "$repo/Makefile" && echo 1)" "$id Makefile has a check target"
  assert_exit 0 in_dir "$repo" env PATH="$TOOLFREE" make -n check
  assert_eq 1 "$(grep -q '\.bearing/state' "$repo/.gitignore" && echo 1)" "$id .gitignore ignores .bearing/state"
  # A stack that ships .env.example tells the developer to copy it to .env;
  # that copy holds real keys and must never be committable.
  if [ -f "$repo/.env.example" ]; then
    assert_exit 0 git -C "$repo" check-ignore -q .env
    assert_exit 1 git -C "$repo" check-ignore -q .env.example
  fi
  # Web stacks carry the browser matrix, visual regression and page budgets;
  # stacks with a database prove every Down with migrate-verify in CI.
  case "$id" in
    react-web|next-app)
      assert_file "$repo/lighthouserc.json"; assert_json "$repo/lighthouserc.json"
      for tg in test-e2e-matrix test-visual test-visual-update bundle-budget lighthouse; do
        assert_eq 1 "$(grep -Eq "^$tg:" "$repo/Makefile" && echo 1)" "$id Makefile has $tg"; done
      for p in chromium firefox webkit mobile-chrome mobile-safari visual; do
        assert_contains "$(cat "$repo/playwright.config.ts")" "name: \"$p\"" "$id playwright project $p"; done
      for j in e2e-matrix visual perf-budget; do
        assert_eq 1 "$(grep -Eq "^$j:" "$repo/.gitlab-ci.yml" && echo 1)" "$id GitLab job $j"
        assert_eq 1 "$(grep -Eq "^  $j:" "$repo/.github/workflows/ci.yml" && echo 1)" "$id GitHub job $j"; done ;;
    go-api|python-api|node-api)
      assert_file "$repo/scripts/schema-snapshot.sql"
      assert_eq 1 "$(grep -Eq '^migrate-verify:' "$repo/Makefile" && echo 1)" "$id Makefile has migrate-verify"
      assert_exit 2 in_dir "$repo" env PATH="$TOOLFREE" make migrate-verify
      assert_contains "$T_OUT" "migrate-verify: psql not installed (postgresql-client), nothing checked"
      assert_eq 1 "$(grep -q 'make migrate-verify' "$repo/.gitlab-ci.yml" && echo 1)" "$id GitLab runs migrate-verify"
      assert_eq 1 "$(grep -q 'make migrate-verify' "$repo/.github/workflows/ci.yml" && echo 1)" "$id GitHub runs migrate-verify" ;;
  esac
  assert_eq 0 "$(grep -rl -E '__(REPO_NAME|REPO_SLUG|STACK|REPO_TYPE|DATABASES|ENTRYPOINT|TRACKER|LEAD|TEAM_GROUP|ORG_ID|KIT_REMOTE|MODULE)__' "$repo" --exclude-dir=.git | wc -l | tr -d ' ')" "$id: no placeholder survives"
  t_end
done

t_begin "stack count"
assert_eq 1 "$([ "$n" -gt 0 ] && echo 1)" "at least one stack scaffolded (did $n)"
t_end

t_begin "go-api --host github and --host gitlab keep only that host's files"
gh="$(tmpdir)/probe-gh"
assert_exit 0 scaffold go-api ProbeGh "$gh" github
assert_contains "$T_OUT" "host: github (--host)"
assert_contains "$T_OUT" "host files: .github/"
assert_file "$gh/.github/workflows/ci.yml"
assert_file "$gh/.github/PULL_REQUEST_TEMPLATE.md"
assert_absent "$gh/.gitlab-ci.yml"
assert_absent "$gh/.gitlab"
gl="$(tmpdir)/probe-gl"
assert_exit 0 scaffold go-api ProbeGl "$gl" gitlab
assert_contains "$T_OUT" "host: gitlab (--host)"
assert_contains "$T_OUT" "host files: .gitlab-ci.yml .gitlab/"
assert_file "$gl/.gitlab-ci.yml"
assert_file "$gl/.gitlab/merge_request_templates/Default.md"
assert_absent "$gl/.github"
assert_exit 2 scaffold go-api ProbeBad "$(tmpdir)/probe-bad" bitbucket
assert_contains "$T_OUT" "--host must be gitlab, github or both (got 'bitbucket')"
t_end

t_begin "a non-empty target and a bad name are refused"
assert_exit 1 scaffold go-api ProbeGh "$gh" both
assert_contains "$T_OUT" "exists and is not empty; use brg-adopt"
assert_exit 2 scaffold go-api probe-lower "$(tmpdir)/probe-lower" both
assert_contains "$T_OUT" "name must be PascalCase"
t_end

# brg-autopilot launch writes its log into .bearing/state before the repo stage
# scaffolds the directory; a rewrite there replaced the log the running session
# still held open, so everything after the scaffold went to a deleted file.
t_begin "a run's state under .bearing is neither rewritten nor counted"
fresh="$(tmpdir)/probe-state-fresh"
assert_exit 0 scaffold go-api ProbeState "$fresh" gitlab
want="$(printf '%s' "$T_OUT" | sed -nE 's/.*brg-scaffold: ([0-9]+) files written.*/\1/p')"
st="$(tmpdir)/probe-state"
mkdir -p "$st/.bearing/state"
printf 'stream line __REPO_NAME__\n' > "$st/.bearing/state/autopilot.log"
printf '{"statement": "keep __MODULE__ as typed"}\n' > "$st/.bearing/state/autopilot.json"
ino="$(ls -i "$st/.bearing/state/autopilot.log" | awk '{print $1}')"
assert_exit 0 scaffold go-api ProbeState "$st" gitlab
assert_contains "$T_OUT" "brg-scaffold: $want files written"
assert_contains "$T_OUT" " 0 files with unfilled placeholders)"
assert_eq "$ino" "$(ls -i "$st/.bearing/state/autopilot.log" | awk '{print $1}')" "the open log keeps its inode"
assert_eq "stream line __REPO_NAME__" "$(cat "$st/.bearing/state/autopilot.log")" "the log is untouched"
assert_eq '{"statement": "keep __MODULE__ as typed"}' "$(cat "$st/.bearing/state/autopilot.json")" "the run state is untouched"
t_end

# ---- make check with no toolchain must fail, never pass silently
t_begin "python-api: make check with no toolchain skips every gate and fails"
py="$(tmpdir)/probe-py-check"
assert_exit 0 scaffold python-api ProbePyCheck "$py" both
assert_exit 2 in_dir "$py" env -u CI -u BEARING_ALLOW_SKIP PATH="$TOOLFREE" make check
assert_contains "$T_OUT" "format-check: SKIPPED (uv not installed)"
assert_contains "$T_OUT" "check: 0 gates run, 5 skipped"
assert_contains "$T_OUT" "check: FAILED, 5 gate(s) skipped"
skipped="$(printf '%s\n' "$T_OUT" | grep -c ': SKIPPED (')"
assert_eq 5 "$skipped" "one SKIPPED line per gate"
assert_absent "$py/.bearing/state/.check-passed"
assert_exit 0 in_dir "$py" env -u CI PATH="$TOOLFREE" BEARING_ALLOW_SKIP=1 make check
assert_contains "$T_OUT" "check: 0 gates run, 5 skipped"
assert_contains "$T_OUT" "check: passed with skips (BEARING_ALLOW_SKIP=1 is a local convenience; CI never sets it)"
assert_exit 2 in_dir "$py" env PATH="$TOOLFREE" CI=true BEARING_ALLOW_SKIP=1 make check
assert_contains "$T_OUT" "check: FAILED, 5 gate(s) skipped" "BEARING_ALLOW_SKIP is ignored under CI"
t_end

t_begin "go-api: make check with no toolchain fails closed at the first empty gate"
go="$(tmpdir)/probe-go-check"
assert_exit 0 scaffold go-api ProbeGoCheck "$go" both
assert_exit 2 in_dir "$go" env -u CI -u BEARING_ALLOW_SKIP PATH="$TOOLFREE" make check
assert_contains "$T_OUT" "vet: 0 packages, nothing checked"
assert_contains "$T_OUT" "check: vet failed"
assert_not_contains "$T_OUT" "check: passed" "no pass without go"
assert_absent "$go/.bearing/state/.check-passed"
assert_exit 2 in_dir "$go" env -u CI PATH="$TOOLFREE" BEARING_ALLOW_SKIP=1 make check
assert_contains "$T_OUT" "check: vet failed" "BEARING_ALLOW_SKIP cannot rescue a gate with zero input"
t_end

echo "scaffold_each_stack: $n stacks scaffolded (host both), 2 host variants, 2 tool-free make check runs"
t_summary
