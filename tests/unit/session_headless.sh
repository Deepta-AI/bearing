#!/usr/bin/env bash
# tests/unit/session_headless.sh: a non-interactive session (brg-autopilot's
# claude -p child sets BEARING_AUTOPILOT=1; anyone sets BEARING_NONINTERACTIVE=1
# in the environment or bearing.env) gets no "Ask the user with
# AskUserQuestion" line at startup: not for the update offer, the learning
# consent or the resume. An interactive session still gets all three.
set -u
. "$(dirname "$0")/../lib/assert.sh"
export HOME; HOME="$(tmpdir)"
# This test offers its own fake release; assert.sh turns the check off.
unset BEARING_UPDATE_CHECK
remote="$(tmpdir)/r.git"; git init -q --bare "$remote"
src="$(tmpdir)/src"; git init -q -b main "$src"
git -C "$src" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m v
git -C "$src" tag v99.0.0; git -C "$src" push -q "$remote" v99.0.0 2>/dev/null
mkdir -p "$HOME/.claude/plugins"
printf '{"bearing":{"source":{"source":"git","url":"%s"}}}\n' "$remote" > "$HOME/.claude/plugins/known_marketplaces.json"

r="$(tmpdir)"; git -C "$r" init -q -b feature/TASK-7-x; mkdir -p "$r/.bearing/state"
git -C "$r" -c user.email=t@example.com -c user.name=t commit -q --allow-empty -m init
printf '# Handoff\nNext: finish the parser\n' > "$r/.bearing/state/feature_TASK-7-x.md"
cfg="$(tmpdir)"; mkdir -p "$cfg/bearing"; : > "$cfg/bearing/bearing.env"
sess() { rm -f "$cfg/bearing/update-check"; ( cd "$r" && env XDG_CONFIG_HOME="$cfg" BEARING_NO_GATE_LOG=1 "$@" bash "$GUARD" session --id s1 --source startup ); }

t_begin "interactive startup asks about the update, learning and resume"
assert_exit 0 sess
assert_contains "$T_OUT" "-> 99.0.0" "the update offer fired"
assert_eq 3 "$(printf '%s\n' "$T_OUT" | grep -c 'AskUserQuestion')" "three asks"
t_end

for sw in BEARING_AUTOPILOT=1 BEARING_NONINTERACTIVE=1; do
  t_begin "$sw: no asks"
  assert_exit 0 sess "$sw"
  assert_not_contains "$T_OUT" "AskUserQuestion" "$sw"
  assert_contains "$T_OUT" "bearing session: branch=feature/TASK-7-x" "the rest of the block stays"
  assert_contains "$T_OUT" "Resume TASK-7" "resume still says where things stand"
  t_end
done

t_begin "BEARING_NONINTERACTIVE=1 in bearing.env: no asks"
echo BEARING_NONINTERACTIVE=1 > "$cfg/bearing/bearing.env"
assert_exit 0 sess
assert_not_contains "$T_OUT" "AskUserQuestion"
echo BEARING_NONINTERACTIVE=0 > "$cfg/bearing/bearing.env"
assert_exit 0 sess
assert_contains "$T_OUT" "AskUserQuestion" "0 means interactive"
t_end
t_summary
