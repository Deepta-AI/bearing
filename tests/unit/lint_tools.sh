#!/usr/bin/env bash
# tests/unit/lint_tools.sh: bin/lint-skill-tools.py finds a command a skill
# body runs but its allowed-tools does not grant, accepts a granted one, a
# guard-blocked one (printed for the engineer), an allow-file row and a
# printed message; reports a stale allow row; and fails on an empty or
# missing skills directory.
set -u
. "$(dirname "$0")/../lib/assert.sh"
LINT="$KIT/bin/lint-skill-tools.py"

# skill <dir> <name> <allowed-tools> <steps body>: one fixture skill.
skill() {
  mkdir -p "$1/$2"
  printf -- '---\nname: %s\ndescription: fixture\nallowed-tools: %s\n---\n\n# %s\n\n## Steps\n\n%s\n\n## Gotchas\n\n- `rm -rf build` here is prose.\n' \
    "$2" "$3" "$2" "$4" > "$1/$2/SKILL.md"
}

d="$(tmpdir)"; empty="$(tmpdir)/allow"; : > "$empty"

t_begin "an ungranted command is reported with its file and line"
skill "$d/a" sk-one "Read, Bash(git diff:*)" '1. Run `git diff --stat` then `make check 2>&1 | tail -40`.'
assert_exit 1 python3 "$LINT" "$d/a" "$empty"
assert_contains "$T_OUT" "sk-one/SKILL.md:11: \`make check 2>&1\` is not granted"
assert_contains "$T_OUT" "sk-one/SKILL.md:11: \`tail -40\` is not granted"
assert_contains "$T_OUT" "3 commands examined"
assert_not_contains "$T_OUT" "git diff --stat\` is not granted"
assert_not_contains "$T_OUT" "rm -rf"
t_end

t_begin "granted, glob-granted, Grep-met and placeholder commands pass"
skill "$d/b" sk-two "Read, Grep, Bash(make:*), Bash(bash *bin/brg-x *)" \
  '1. `make check`, `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-x" <name>`, `git ls-files | grep -c x`, `${CLAUDE_PLUGIN_ROOT}/bin/brg-x`.'
assert_exit 1 python3 "$LINT" "$d/b" "$empty"
assert_contains "$T_OUT" "\`git ls-files\` is not granted"
assert_contains "$T_OUT" "1 problems"
t_end

t_begin "a guard-blocked command and a printed message are exempt"
skill "$d/c" sk-three "Read" '1. Print `git push -u origin HEAD`; stop with "run `git init` and rerun".'
assert_exit 0 python3 "$LINT" "$d/c" "$empty"
assert_contains "$T_OUT" "1 exempt"
t_end

t_begin "an allow row exempts a command; a stale row is a problem"
skill "$d/e" sk-four "Read" '1. Add `make licenses` to the Makefile.'
printf 'sk-four|make licenses|a target the skill adds\n' > "$d/allow1"
assert_exit 0 python3 "$LINT" "$d/e" "$d/allow1"
printf 'sk-four|make licenses|a target the skill adds\nsk-four|make gone|old\n' > "$d/allow2"
assert_exit 1 python3 "$LINT" "$d/e" "$d/allow2"
assert_contains "$T_OUT" "stale row sk-four|make gone"
printf 'sk-four|make licenses\n' > "$d/allow3"
assert_exit 1 python3 "$LINT" "$d/e" "$d/allow3"
assert_contains "$T_OUT" "needs skill|prefix|reason"
t_end

t_begin "zero commands, zero skills and a missing directory fail"
skill "$d/f" sk-five "Read" '1. Read the file.'
assert_exit 1 python3 "$LINT" "$d/f" "$empty"
assert_contains "$T_OUT" "nothing checked"
mkdir -p "$d/g"
assert_exit 1 python3 "$LINT" "$d/g" "$empty"
assert_contains "$T_OUT" "0 skills"
assert_exit 1 python3 "$LINT" "$d/missing" "$empty"
assert_contains "$T_OUT" "no skills directory"
t_end

t_begin "the kit's own skills pass"
assert_exit 0 python3 "$LINT"
assert_contains "$T_OUT" "0 problems"
t_end

t_summary
