#!/usr/bin/env bash
# tests/unit/skill_evals.sh: bin/skill-evals.py refuses empty input with a
# message, and status counts the skills, the evals and the measured ones.
set -u
. "$(dirname "$0")/../lib/assert.sh"
SE="$KIT/bin/skill-evals.py"

t_begin "prepare refuses a skill with no evals"
assert_exit 1 python3 "$SE" prepare no-such-skill
assert_contains "$T_OUT" "evals.json, nothing prepared"
t_end

t_begin "timing refuses a path that is not a run directory"
assert_exit 1 python3 "$SE" timing "$(tmpdir)/missing" 1 1
assert_contains "$T_OUT" "is not a run directory"
t_end

t_begin "unblind refuses an iteration with nothing in it"
assert_exit 1 python3 "$SE" unblind no-such-skill --iteration 99
assert_contains "$T_OUT" "0 arm folders unblinded"
t_end

t_begin "status counts skills, evals and measured verdicts"
assert_exit 0 python3 "$SE" status
n=$(ls "$KIT"/skills/*/SKILL.md | wc -l | tr -d ' ')
e=$(ls "$KIT"/evals/*/evals.json 2>/dev/null | wc -l | tr -d ' ')
assert_contains "$T_OUT" "skill-evals: $n skills, $e with evals,"
t_end

t_summary
