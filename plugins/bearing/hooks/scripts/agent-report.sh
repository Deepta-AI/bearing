#!/usr/bin/env bash
# SubagentStop (bearing:verifier, bearing:reviewer, bearing:security-auditor):
# a skill reads these agents' reports by their output contract, so a report
# that does not start the way agents/<name>.md says is sent back once, with
# the line it must start with. The second stop always passes
# (stop_hook_active), so an agent that cannot comply is never held in a loop;
# gates.log records ok, resent or passed-unshaped. Exit 2 sends it back.
set -u
# No program runs before lib.sh resets the environment, so no dirname here;
# the next script starts with "$BASH" from ${0%/*}, never found on PATH.
# shellcheck source=lib.sh
case "$0" in (*/*) . "${0%/*}/lib.sh" ;; (*) . ./lib.sh ;; esac
guard="${0%/*}/../../bin/brg-guard"
agent="$(json_field agent_type)"
case "$agent" in
  (bearing:verifier) want='^Verdict: (CONFIRMED|REFUTED|UNCERTAIN)'; line='Verdict: CONFIRMED | REFUTED | UNCERTAIN' ;;
  (bearing:reviewer|bearing:security-auditor) want='^## Findings \('; line='## Findings (N ...)' ;;
  (*) exit 0 ;;
esac
name="${agent#bearing:}"
msg="$(json_field last_assistant_message)"
if [ "$msg" = "__BRG_UNPARSED__" ]; then
  "$BASH" "$guard" log agent-report not-run "$name" >/dev/null 2>&1
  exit 0
fi
if printf '%s\n' "$msg" | grep -Eq -- "$want"; then
  "$BASH" "$guard" log agent-report ok "$name" >/dev/null 2>&1
  exit 0
fi
if [ "$(json_field stop_hook_active)" = true ]; then
  "$BASH" "$guard" log agent-report passed-unshaped "$name" >/dev/null 2>&1
  exit 0
fi
"$BASH" "$guard" log agent-report resent "$name" >/dev/null 2>&1
echo "Bearing: the skill that started you reads your report by the output contract in agents/$name.md. Reply again with the report in that shape, starting with the line: $line" >&2
exit 2
