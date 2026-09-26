#!/usr/bin/env bash
# tests/unit/lint_evals.sh: bin/lint-skill-evals.py accepts a skill with
# well-formed skill-creator evals and a pending legacy skill; fails a new
# skill without evals, evals left beside a skill, evals for no skill, a pending row for a skill that has evals (the list
# only shrinks), a malformed evals.json, a missing input file, a pending row
# naming no skill, and an empty skills directory.
set -u
. "$(dirname "$0")/../lib/assert.sh"
LINT="$KIT/bin/lint-skill-evals.py"

sk() { mkdir -p "$1/skills/$2"; printf -- '---\nname: %s\n---\n' "$2" > "$1/skills/$2/SKILL.md"; }
ev() { mkdir -p "$1/evals/$2"; printf '%s\n' "$3" > "$1/evals/$2/evals.json"; }
GOOD='{"skill_name":"sk-a","evals":[{"id":1,"prompt":"review my branch","expected_output":"ranked findings","files":[],"expectations":["each finding names path:line"]}]}'

t_begin "evals present and a pending legacy skill pass"
d="$(tmpdir)"; sk "$d" sk-a; sk "$d" sk-b; ev "$d" sk-a "$GOOD"; printf '# legacy\nsk-b\n' > "$d/pending"
assert_exit 0 python3 "$LINT" "$d/skills" "$d/evals" "$d/pending"
assert_contains "$T_OUT" "lint-evals: 2 skills, 1 with evals (1 cases), 1 pending, 0 problems"
t_end

t_begin "a new skill without evals fails; a pending skill with evals fails"
d="$(tmpdir)"; sk "$d" sk-a; sk "$d" sk-c; ev "$d" sk-a "$GOOD"; printf 'sk-a\nsk-gone\n' > "$d/pending"
assert_exit 1 python3 "$LINT" "$d/skills" "$d/evals" "$d/pending"
assert_contains "$T_OUT" "sk-c: no evals/sk-c/evals.json"
assert_contains "$T_OUT" "sk-a: has evals now; remove it"
assert_contains "$T_OUT" "sk-gone is not a skill"
t_end

t_begin "malformed evals fail with the reason"
d="$(tmpdir)"; sk "$d" sk-a; : > "$d/pending"
ev "$d" sk-a '{"skill_name":"sk-x","evals":[{"id":1,"prompt":"p","expected_output":"e","expectations":[]},{"id":1,"prompt":"","expected_output":"e","files":["files/in.txt"],"expectations":["x"]}]}'
assert_exit 1 python3 "$LINT" "$d/skills" "$d/evals" "$d/pending"
assert_contains "$T_OUT" "skill_name is 'sk-x'"
assert_contains "$T_OUT" "case 1: no expectations"
assert_contains "$T_OUT" "case 1: duplicate id"
assert_contains "$T_OUT" "case 1: no prompt"
assert_contains "$T_OUT" "input file files/in.txt does not exist"
ev "$d" sk-a 'not json'
assert_exit 1 python3 "$LINT" "$d/skills" "$d/evals" "$d/pending"
assert_contains "$T_OUT" "is not JSON"
ev "$d" sk-a '{"skill_name":"sk-a","evals":[]}'
assert_exit 1 python3 "$LINT" "$d/skills" "$d/evals" "$d/pending"
assert_contains "$T_OUT" "has no cases"
t_end

t_begin "evals beside a skill and evals for no skill fail"
d="$(tmpdir)"; sk "$d" sk-a; ev "$d" sk-a "$GOOD"; : > "$d/pending"
mkdir -p "$d/skills/sk-a/evals"; ev "$d" sk-zz "$GOOD"
assert_exit 1 python3 "$LINT" "$d/skills" "$d/evals" "$d/pending"
assert_contains "$T_OUT" "skills/sk-a/evals/ exists"
assert_contains "$T_OUT" "evals/sk-zz: no skill of that name"
t_end

t_begin "zero skills and a missing directory fail"
d="$(tmpdir)"; mkdir -p "$d/skills"
assert_exit 1 python3 "$LINT" "$d/skills" "$d/evals" "$d/pending"
assert_contains "$T_OUT" "0 skills, nothing checked"
assert_exit 1 python3 "$LINT" "$d/none" "$d/evals"
assert_contains "$T_OUT" "no skills directory"
t_end

t_begin "the kit's own skills pass"
assert_exit 0 python3 "$LINT"
t_end

t_summary
