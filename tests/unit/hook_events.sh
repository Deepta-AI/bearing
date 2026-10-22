#!/usr/bin/env bash
# tests/unit/hook_events.sh: the hooks on StopFailure, PostToolUseFailure,
# PermissionDenied and SubagentStop. stop-failure.sh writes the checkpoint and
# logs the error type; tool-failure.sh logs the tool name only; agent-report.sh
# sends a Bearing review agent back once when its report misses its output
# contract, and never twice. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
HS="$KIT/plugins/bearing/hooks/scripts"

repo="$(tmpdir)"; git init -q "$repo"; mkdir -p "$repo/.bearing/state"
log="$repo/.bearing/state/gates.log"
hook() { T_IN="$2"; t_run bash -c "cd '${3:-$repo}' && bash '$HS/$1'"; }  # hook <script> <json> [dir]
last() { tail -1 "$log" | cut -f2,3,5; }
tab="$(printf '\t')"

t_begin "StopFailure writes the checkpoint and logs the error type"
hook stop-failure.sh '{"hook_event_name":"StopFailure","error":"rate_limit","error_details":"429"}'
assert_eq 0 "$T_RC" "exit"
assert_eq "stop-failure${tab}rate_limit${tab}" "$(last)" "logged"
assert_file "$repo/.bearing/state/main.checkpoint.md"
t_end

t_begin "an error type that is not a plain word is logged as unknown"
hook stop-failure.sh '{"error":"rate limit; rm -rf /"}'
assert_eq "stop-failure${tab}unknown${tab}" "$(last)" "logged"
t_end

t_begin "a failed tool is logged by name only, never its error text"
hook tool-failure.sh '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash","tool_input":{"command":"cat secret.env"},"error":"token=abc123"}'
assert_eq 0 "$T_RC" "exit"
assert_eq "tool-failure${tab}Bash${tab}" "$(last)" "logged"
assert_not_contains "$(cat "$log")" "abc123"
assert_not_contains "$(cat "$log")" "secret.env"
t_end

t_begin "a permission denial is logged under its own gate"
hook tool-failure.sh '{"hook_event_name":"PermissionDenied","tool_name":"mcp__github__push","reason":"[no-push] pushing"}'
assert_eq "permission-denied${tab}mcp__github__push${tab}" "$(last)" "logged"
t_end

t_begin "a verifier report in its contract passes"
hook agent-report.sh '{"agent_type":"bearing:verifier","last_assistant_message":"Verdict: REFUTED\nFinding: a.go:3 x","stop_hook_active":false}'
assert_eq 0 "$T_RC" "exit"
assert_eq "agent-report${tab}ok${tab}verifier" "$(last)" "logged"
t_end

t_begin "a reviewer report out of contract is sent back once with the line it must start with"
hook agent-report.sh '{"agent_type":"bearing:reviewer","last_assistant_message":"Looks good to me.","stop_hook_active":false}'
assert_eq 2 "$T_RC" "exit"
assert_contains "$T_OUT" "agents/reviewer.md"
assert_contains "$T_OUT" "## Findings (N ...)"
assert_eq "agent-report${tab}resent${tab}reviewer" "$(last)" "logged"
t_end

t_begin "the second stop always passes, so no agent is held in a loop"
hook agent-report.sh '{"agent_type":"bearing:reviewer","last_assistant_message":"Still fine.","stop_hook_active":true}'
assert_eq 0 "$T_RC" "exit"
assert_eq "agent-report${tab}passed-unshaped${tab}reviewer" "$(last)" "logged"
t_end

t_begin "other agents are left alone"
n="$(wc -l < "$log" | tr -d ' ')"
hook agent-report.sh '{"agent_type":"Explore","last_assistant_message":"anything","stop_hook_active":false}'
assert_eq 0 "$T_RC" "exit"
assert_eq "$n" "$(wc -l < "$log" | tr -d ' ')" "nothing logged"
t_end

t_begin "outside a Bearing repository the hooks write nothing and exit 0"
plain="$(tmpdir)"; git init -q "$plain"
hook tool-failure.sh '{"hook_event_name":"PostToolUseFailure","tool_name":"Bash"}' "$plain"
assert_eq 0 "$T_RC" "exit"
assert_eq "no" "$([ -e "$plain/.bearing" ] && echo yes || echo no)" ".bearing created"
t_end

t_begin "hooks.json wires the four events to these scripts"
h="$KIT/plugins/bearing/hooks/hooks.json"
assert_contains "$(jq -r '.hooks.StopFailure[0].hooks[0].command' "$h")" "stop-failure.sh"
assert_contains "$(jq -r '.hooks.PostToolUseFailure[0].hooks[0].command' "$h")" "tool-failure.sh"
assert_contains "$(jq -r '.hooks.PermissionDenied[0].hooks[0].command' "$h")" "tool-failure.sh"
assert_eq '^bearing:(verifier|reviewer|security-auditor)$' "$(jq -r '.hooks.SubagentStop[0].matcher' "$h")" "matcher"
t_end

t_summary
