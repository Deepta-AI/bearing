#!/usr/bin/env bash
# tests/integration/adopt_idempotent.sh: bin/brg-adopt on a repository that
# already carries the standard. Scaffold go-api (tool-free PATH, so no
# install step), delete Makefile and .gitlab-ci.yml, adopt twice: the first
# run adds exactly those two, the second adds and conflicts nothing. Edit
# AGENTS.md locally and adopt again: a .bearing-new proposal appears beside it
# and the local file is untouched. A fresh repository with a github.com
# origin gets .github/ only, inferred from the remote and again with --host
# github; a gitlab origin gets the GitLab set only. The directory name is
# the scaffold's slug so adopt derives the same PascalCase name and every
# shared file compares identical. A repository whose core.hooksPath is
# .husky keeps it: adopt reports a conflict with the fix and still writes
# .githooks/. A team's own Makefile gets the Stop-gate line as a Makefile.bearing-new
# proposal (never an edit); no check target, or check over several rules, gets a note.
set -u
. "$(dirname "$0")/../lib/assert.sh"
TOOLFREE="$(minimal_path bash sh git python3 make sed grep find cut sort uniq wc tr mktemp mv cp rm mkdir chmod ls cat basename dirname head tail stat touch env date awk cmp diff)"

scaffold() { env -u BEARING_TRACKER -u BEARING_GIT_HOST -u BEARING_ORG_ID -u BEARING_KIT_REMOTE -u BEARING_TASK_ID_PREFIX PATH="$TOOLFREE" BEARING_ENV=/nonexistent bash "$KIT/bin/brg-scaffold" "$1" "$2" --dir "$3" --host "$4"; }
adopt() { env -u BEARING_TRACKER -u BEARING_GIT_HOST -u BEARING_ORG_ID -u BEARING_KIT_REMOTE -u BEARING_TASK_ID_PREFIX PATH="$TOOLFREE" BEARING_ENV=/nonexistent bash "$KIT/bin/brg-adopt" "$@"; }
assert_absent() { _t_count; if [ -e "$1" ]; then _t_fail "should not exist: $1"; fi; }
count_line() { printf '%s\n' "$1" | grep -c "^$2" || true; }
runs=0

repo="$(tmpdir)/probe-go"
t_begin "scaffold go-api, then drop its build files"
assert_exit 0 scaffold go-api ProbeGo "$repo" both
rm -f "$repo/Makefile" "$repo/.gitlab-ci.yml"
assert_absent "$repo/Makefile"
t_end

t_begin "first adopt adds Makefile and .gitlab-ci.yml, nothing else"
assert_exit 0 adopt --dir "$repo" --stack go-api; runs=$((runs+1))
assert_contains "$T_OUT" "host: both (default)"
assert_contains "$T_OUT" "added     Makefile"
assert_contains "$T_OUT" "added     .gitlab-ci.yml"
assert_eq 2 "$(count_line "$T_OUT" 'added ')" "exactly two files added"
assert_eq 0 "$(count_line "$T_OUT" 'conflict ')" "no conflicts against a fresh scaffold"
assert_contains "$T_OUT" "added 2, kept "
assert_contains "$T_OUT" ", conflicts 0 (core.hooksPath set)"
assert_not_contains "$T_OUT" "note: CLAUDE.md does not start with @AGENTS.md"
assert_file "$repo/Makefile"
assert_file "$repo/.gitlab-ci.yml"
assert_eq 1 "$(cmp -s "$repo/Makefile" "$KIT/skills/go/templates/Makefile" || echo 1)" "the adopted Makefile has its placeholders filled"
assert_eq 1 "$(grep -q '^# ProbeGo (Go service)' "$repo/Makefile" && echo 1)" "Makefile names the repository"
assert_eq 0 "$(grep -c '__REPO_' "$repo/Makefile" "$repo/.gitlab-ci.yml" | awk -F: '{s+=$2} END {print s+0}')" "no placeholder left in the added files"
t_end

t_begin "second adopt is a no-op: added 0, conflicts 0"
before="$(find "$repo" -type f -not -path '*/.git/*' | sort)"
assert_exit 0 adopt --dir "$repo" --stack go-api; runs=$((runs+1))
assert_eq 0 "$(count_line "$T_OUT" 'added ')"
assert_eq 0 "$(count_line "$T_OUT" 'conflict ')"
assert_contains "$T_OUT" "added 0, kept "
assert_contains "$T_OUT" ", conflicts 0 (core.hooksPath set)"
assert_eq "$before" "$(find "$repo" -type f -not -path '*/.git/*' | sort)" "no file appeared or vanished"
kept="$(printf '%s\n' "$T_OUT" | sed -n 's/.*added 0, kept \([0-9]*\),.*/\1/p')"
assert_eq 1 "$([ "${kept:-0}" -gt 10 ] && echo 1)" "the standard's shared files were all kept ($kept)"
t_end

t_begin "a locally edited AGENTS.md gets an .bearing-new proposal and stays untouched"
standard_copy="$(cat "$repo/AGENTS.md")"
printf '\n## Local addition\n\nKept by the team.\n' >> "$repo/AGENTS.md"
local_copy="$(cat "$repo/AGENTS.md")"
assert_exit 0 adopt --dir "$repo" --stack go-api; runs=$((runs+1))
assert_contains "$T_OUT" "conflict  AGENTS.md  (proposal at AGENTS.md.bearing-new)"
assert_eq 1 "$(count_line "$T_OUT" 'conflict ')" "only AGENTS.md conflicts"
assert_contains "$T_OUT" ", conflicts 1 (core.hooksPath set)"
assert_file "$repo/AGENTS.md.bearing-new"
assert_eq "$local_copy" "$(cat "$repo/AGENTS.md")" "AGENTS.md was not overwritten"
assert_not_contains "$(cat "$repo/AGENTS.md.bearing-new")" "## Local addition" "the proposal is the standard's text"
assert_eq "$standard_copy" "$(cat "$repo/AGENTS.md.bearing-new")" "the proposal is exactly the scaffolded AGENTS.md"
t_end

t_begin "a github.com origin: .github/ only, inferred and explicit"
gh="$(tmpdir)/probe-gh"
mkdir -p "$gh"; git -C "$gh" init -q; git -C "$gh" remote add origin https://github.com/acme/probe-gh.git
assert_exit 0 adopt --dir "$gh" --stack go-api; runs=$((runs+1))
assert_contains "$T_OUT" "host: github (origin remote)"
assert_file "$gh/.github/PULL_REQUEST_TEMPLATE.md"
assert_file "$gh/.github/workflows/ci.yml"
assert_file "$gh/Makefile"
assert_file "$gh/AGENTS.md"
assert_file "$gh/.claude/rules/go.md"
assert_absent "$gh/.gitlab-ci.yml"
assert_absent "$gh/.gitlab"
assert_eq ".githooks" "$(git -C "$gh" config core.hooksPath)"
assert_contains "$T_OUT" "conflicts 0 (core.hooksPath set)"
gh2="$(tmpdir)/probe-gh-two"
mkdir -p "$gh2"; git -C "$gh2" init -q; git -C "$gh2" remote add origin git@github.com:acme/probe-gh-two.git
assert_exit 0 adopt --dir "$gh2" --host github; runs=$((runs+1))
assert_contains "$T_OUT" "host: github (--host)"
assert_file "$gh2/.github/PULL_REQUEST_TEMPLATE.md"
assert_absent "$gh2/.gitlab-ci.yml"
assert_absent "$gh2/.gitlab"
assert_absent "$gh2/Makefile"
assert_eq 0 "$(count_line "$T_OUT" 'added     .gitlab')" "no GitLab file offered"
t_end

t_begin "a gitlab origin: the GitLab set only"
gl="$(tmpdir)/probe-gl"
mkdir -p "$gl"; git -C "$gl" init -q; git -C "$gl" remote add origin git@gitlab.example.com:group/probe-gl.git
assert_exit 0 adopt --dir "$gl" --stack python-api; runs=$((runs+1))
assert_contains "$T_OUT" "host: gitlab (origin remote)"
assert_file "$gl/.gitlab-ci.yml"
assert_file "$gl/.gitlab/merge_request_templates/Default.md"
assert_file "$gl/.claude/rules/python.md"
assert_absent "$gl/.github"
assert_exit 2 adopt --dir "$gl" --host bitbucket; runs=$((runs+1))
assert_contains "$T_OUT" "--host must be gitlab, github or both (got 'bitbucket')"
t_end

t_begin "a core.hooksPath set elsewhere (Husky) is kept and reported, the hooks still written"
hu="$(tmpdir)/probe-husky"
mkdir -p "$hu/.husky"; git -C "$hu" init -q; git -C "$hu" config core.hooksPath .husky
printf '#!/bin/sh\nnpx lint-staged\n' > "$hu/.husky/pre-commit"
assert_exit 0 adopt --dir "$hu" --host gitlab; runs=$((runs+1))
assert_eq ".husky" "$(git -C "$hu" config core.hooksPath)" "core.hooksPath unchanged"
assert_contains "$T_OUT" "conflict  core.hooksPath is .husky; left unchanged"
assert_contains "$T_OUT" '.husky/pre-push:  .githooks/pre-push "$@" || exit $?'
assert_contains "$T_OUT" "or: git -C \"$hu\" config core.hooksPath .githooks"
assert_contains "$T_OUT" ", conflicts 1 (core.hooksPath left at .husky: conflict)"
assert_eq 1 "$(count_line "$T_OUT" 'conflict ')" "the hooks path is the only conflict"
for h in commit-msg pre-commit pre-push; do assert_file "$hu/.githooks/$h"; done
assert_eq "$(printf '#!/bin/sh\nnpx lint-staged')" "$(cat "$hu/.husky/pre-commit")" "the Husky hook is untouched"
assert_exit 0 adopt --dir "$hu" --host gitlab; runs=$((runs+1))
assert_eq ".husky" "$(git -C "$hu" config core.hooksPath)" "still unchanged on the second run"
assert_contains "$T_OUT" "added 0, kept "
git -C "$hu" config core.hooksPath .githooks/
assert_exit 0 adopt --dir "$hu" --host gitlab; runs=$((runs+1))
assert_contains "$T_OUT" ", conflicts 0 (core.hooksPath set)" "a trailing slash on .githooks is ours"
t_end

t_begin "a team's own Makefile: the gate line is proposed, never written in place"
own="$(tmpdir)/probe-own"
mkdir -p "$own"; git -C "$own" init -q
printf 'build:\n\tgo build ./...\n\ncheck: build \\\n  vet\n\tgo test ./...\n\t@echo "check: ok"\n\nvet:\n\tgo vet ./...\n' > "$own/Makefile"
original="$(cat "$own/Makefile")"
assert_exit 0 adopt --dir "$own" --stack go-api; runs=$((runs+1))
assert_contains "$T_OUT" "conflict  Makefile  (proposal at Makefile.bearing-new: make check does not record a pass"
assert_eq "$original" "$(cat "$own/Makefile")" "the team's Makefile is untouched"
assert_file "$own/Makefile.bearing-new"
prop="$(cat "$own/Makefile.bearing-new")"
assert_contains "$prop" "$(printf '\t@echo "check: ok"\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n\nvet:')" "the gate line ends the check recipe, before the next rule"
assert_eq 1 "$(printf '%s\n' "$prop" | grep -c 'check-passed')" "added once"
# the proposal really records a pass: make check with stand-in recipes
fake="$(tmpdir)/fake-make"; mkdir -p "$fake"
sed -e 's/go build .*/@true/' -e 's/go vet .*/@true/' -e 's/go test .*/@true/' "$own/Makefile.bearing-new" > "$fake/Makefile"
( cd "$fake" && make -s check >/dev/null 2>&1 )
assert_file "$fake/.bearing/state/.check-passed"
t_end

t_begin "a Makefile with no check, or check split over rules, gets a note instead"
nochk="$(tmpdir)/probe-nochk"; mkdir -p "$nochk"; git -C "$nochk" init -q
printf 'build:\n\ttrue\n' > "$nochk/Makefile"
assert_exit 0 adopt --dir "$nochk" --stack go-api; runs=$((runs+1))
assert_contains "$T_OUT" "note: Makefile has no check target"
assert_absent "$nochk/Makefile.bearing-new"
split="$(tmpdir)/probe-split"; mkdir -p "$split"; git -C "$split" init -q
printf 'check:: lint\n\ttrue\ncheck:: test\n\ttrue\n' > "$split/Makefile"
assert_exit 0 adopt --dir "$split" --stack go-api; runs=$((runs+1))
assert_contains "$T_OUT" "is not one rule this can extend"
assert_contains "$T_OUT" "@mkdir -p .bearing/state && touch .bearing/state/.check-passed"
assert_absent "$split/Makefile.bearing-new"
t_end

# A stdlib python-cli repository once got a uv CI calling make targets it lacked
# and a CLAUDE.md naming uv, mypy and src/app/cli.py, none of which it had.
t_begin "a repository with its own Makefile and none of the stack's layout: no stack CI, no stack snapshot"
py="$(tmpdir)/probe-notes"; mkdir -p "$py/notes"; git -C "$py" init -q
printf 'check:\n\tpython3 -m unittest -q\n' > "$py/Makefile"; : > "$py/notes/__main__.py"
assert_exit 0 adopt --dir "$py" --stack python-cli --host both; runs=$((runs+1))
assert_contains "$T_OUT" "note: the repository keeps its own Makefile, so the python-cli CI"
assert_contains "$T_OUT" "note: src/app/cli.py is not in this repository"
assert_absent "$py/.gitlab-ci.yml"
assert_absent "$py/.github/workflows/ci.yml"
assert_contains "$(cat "$py/CLAUDE.md")" "Stack:        fill in"
assert_contains "$(cat "$py/CLAUDE.md")" "Entrypoint:   fill in"
assert_not_contains "$(cat "$py/CLAUDE.md")" "uv"
t_end

t_begin "not a git repository and an unknown stack are refused"
plain="$(tmpdir)/plain"; mkdir -p "$plain"
assert_exit 1 adopt --dir "$plain"; runs=$((runs+1))
assert_contains "$T_OUT" "is not a git repository"
assert_exit 2 adopt --dir "$gh" --stack cobol; runs=$((runs+1))
assert_contains "$T_OUT" "unknown stack 'cobol'"
t_end

echo "adopt_idempotent: $runs brg-adopt runs over 9 repositories"
t_summary
