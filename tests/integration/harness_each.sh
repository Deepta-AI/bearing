#!/usr/bin/env bash
# tests/integration/harness_each.sh: generate every harness into a temporary
# git repository with bin/brg-harness, assert the file set and modes, pipe the
# recorded hook fixtures (blocked command substituted at run time) into the
# matching adapter and assert deny; hostile and missing-key inputs must deny
# rather than allow; every JSON file parses; the OpenCode plugin loads.
# Copilot's toolArgs is exercised as an object and as a JSON string. The
# summary counts a harness wired only when its config references every
# adapter and nothing is left as .bearing-new (exit 1 otherwise); the env file is
# parsed, and a value with spaces never runs.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="sh"
BLOCKED="git pu$H origin main"
FIX="$KIT/tests/fixtures/hooks"
VERSION="$(tr -d '[:space:]' < "$KIT/VERSION")"

fixture() { # fixture <relative path>: the fixture text with the placeholders filled
  sed "s|__BLOCKED__|$BLOCKED|g; s|__FILE__|$repo/main.go|g" "$FIX/$1"
}
gen() { # gen <harness>: a fresh repo with the template rules, generated
  repo="$(tmpdir)"
  git -C "$repo" init -q -b main
  mkdir -p "$repo/.claude/rules"
  cp "$KIT/templates/repo/.claude/rules/"*.md "$repo/.claude/rules/"
  printf 'package main\n' > "$repo/main.go"
  assert_exit 0 bash "$KIT/bin/brg-harness" "$1" --dir "$repo" --no-skills
  GEN_OUT="$T_OUT"
}
gates_repo() { # gates_repo <cursor|codex>: make the generated repo one the gates hold (a
  # marker-writing Makefile, a session start mark, a changed file, bad.json)
  mkdir -p "$repo/.bearing/state"
  printf 'check:\n\t@touch .bearing/state/.check-passed\n' > "$repo/Makefile"
  git -C "$repo" add -A >/dev/null 2>&1; git -C "$repo" -c user.email=t@e -c user.name=t commit -qm base >/dev/null 2>&1
  local id=C1; [ "$1" = codex ] && id=X1
  : > "$repo/.bearing/state/.session-$id"; touch -t 202001010000 "$repo/.bearing/state/.session-$id"
  printf '{"a": 1,}\n' > "$repo/bad.json"; printf '{}\n' > "$repo/ok.json"
  printf '# Before compaction\n' > "$repo/.bearing/state/main.compact.md"
}
json_ok() { python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$1" 2>/dev/null; }
assert_json() { _t_count; if json_ok "$1"; then :; else _t_fail "invalid JSON: $1"; fi; }
assert_vendored_guard() {
  assert_file "$repo/.bearing/bin/brg-guard" 755
  assert_contains "$(sed -n 2p "$repo/.bearing/bin/brg-guard")" "BEARING_GUARD_VERSION=\"$VERSION\"" "version stamp"
  assert_file "$repo/.bearing/hooks/read-json.sh" 755
}
adapter_denies() { # adapter_denies <adapter path> <fixture> <expected rc> [stdout must contain]
  T_IN="$(fixture "$2")"; assert_exit "$3" bash "$1"
  [ -z "${4:-}" ] || assert_contains "$T_OUT" "$4" "$1 output"
  assert_contains "$T_OUT" "blocked 'git pu$H'" "$1 names the block"
}

# ---- cursor
t_begin "cursor"
gen cursor
assert_vendored_guard
for f in cursor-shell.sh cursor-edit.sh cursor-check.sh cursor-session.sh cursor-stop.sh; do assert_file "$repo/.bearing/hooks/$f" 755; done
assert_file "$repo/.cursor/hooks.json" 644; assert_json "$repo/.cursor/hooks.json"
assert_file "$repo/.cursor/rules/brg-agents.mdc" 644
assert_file "$repo/.cursor/rules/brg-database.mdc" 644
assert_contains "$(sed -n 3p "$repo/.cursor/rules/brg-testing.mdc")" 'globs: **/*.test.ts,**/*.test.tsx' "cursor globs converted"
adapter_denies "$repo/.bearing/hooks/cursor-shell.sh" cursor/before-shell-execution.json 0 '"permission":"deny"'
T_IN="$(fixture cursor/before-shell-execution-allow.json)"; assert_exit 0 bash "$repo/.bearing/hooks/cursor-shell.sh"
assert_eq '{"permission":"allow"}' "$T_OUT" "cursor allow object"
T_IN="$(fixture claude/post-tool-use.json)"; assert_exit 0 bash "$repo/.bearing/hooks/cursor-edit.sh"
T_IN='{}'; assert_exit 0 bash -c "cd '$repo' && bash .bearing/hooks/cursor-session.sh"
assert_contains "$(printf '%s' "$T_OUT" | jq -r .additional_context)" "bearing session: branch=main"
gates_repo cursor
T_IN='{"conversation_id":"C1","loop_count":0,"status":"completed"}'
assert_exit 0 bash -c "cd '$repo' && bash .bearing/hooks/cursor-stop.sh"
assert_contains "$(printf '%s' "$T_OUT" | jq -r .followup_message)" "since make check last passed" "cursor stop continues once"
T_IN='{"conversation_id":"C1","loop_count":1,"status":"completed"}'
assert_exit 0 bash -c "cd '$repo' && bash .bearing/hooks/cursor-stop.sh"
assert_eq '{}' "$T_OUT" "cursor stop never loops"
T_IN="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$repo/bad.json\"}}"
assert_exit 0 bash -c "cd '$repo' && bash .bearing/hooks/cursor-check.sh"
assert_contains "$(printf '%s' "$T_OUT" | jq -r .additional_context)" "jq found problems in bad.json"
assert_contains "$GEN_OUT" "cursor: 5 of 5 adapters"
t_end

# ---- codex
t_begin "codex"
gen codex
assert_vendored_guard
for f in codex-pretool.sh codex-session.sh codex-edit.sh codex-precompact.sh codex-stop.sh; do assert_file "$repo/.bearing/hooks/$f" 755; done
assert_file "$repo/.codex/hooks.json" 644; assert_json "$repo/.codex/hooks.json"
assert_file "$repo/.codex/rules/bearing.rules" 644
nrules="$(grep -c '^prefix_rule' "$repo/.codex/rules/bearing.rules")"
assert_eq 1 "$([ "$nrules" -ge 80 ] && echo 1)" "codex execpolicy has at least 80 prefix rules (has $nrules)"
assert_contains "$(cat "$repo/.codex/rules/bearing.rules")" "prefix_rule(pattern = [\"git\", \"pu$H\"], decision = \"forbidden\""
assert_contains "$(cat "$repo/.codex/rules/bearing.rules")" 'prefix_rule(pattern = ["kubectl", "delete"]'
adapter_denies "$repo/.bearing/hooks/codex-pretool.sh" codex/pre-tool-use.json 2
gates_repo codex
T_IN='{"session_id":"X1","stop_hook_active":false}'
assert_exit 0 bash -c "cd '$repo' && bash .bearing/hooks/codex-stop.sh"
assert_eq "block" "$(printf '%s' "$T_OUT" | jq -r .decision)" "codex stop blocks once"
T_IN='{"session_id":"X1","stop_hook_active":true}'
assert_exit 0 bash -c "cd '$repo' && bash .bearing/hooks/codex-stop.sh"
assert_eq '{}' "$T_OUT" "codex stop never loops, and prints JSON"
T_IN="$(jq -n --arg p "$(printf '*** Begin Patch\n*** Update File: bad.json\n@@\n-x\n+y\n*** Add File: ok.json\n+{}\n*** End Patch')" '{tool_name: "apply_patch", tool_input: {command: $p}}')"
assert_exit 0 bash -c "cd '$repo' && bash .bearing/hooks/codex-edit.sh"
assert_eq "block" "$(printf '%s' "$T_OUT" | jq -r .decision)" "codex edit check blocks"
assert_contains "$(printf '%s' "$T_OUT" | jq -r .reason)" "jq found problems in bad.json"
assert_not_contains "$T_OUT" "ok.json" "a clean file in the same patch is not reported"
T_IN="{\"session_id\":\"X1\",\"trigger\":\"auto\",\"transcript_path\":\"\"}"
assert_exit 0 bash -c "cd '$repo' && bash .bearing/hooks/codex-precompact.sh"
assert_eq "" "$T_OUT" "codex ignores precompact stdout; nothing printed"
T_IN='{"session_id":"X1","source":"compact"}'
assert_exit 0 bash -c "cd '$repo' && bash .bearing/hooks/codex-session.sh"
assert_contains "$T_OUT" "The context was just summarised"
assert_contains "$GEN_OUT" "codex: 5 of 5 adapters"
t_end

# ---- gemini
t_begin "gemini"
gen gemini
assert_vendored_guard
for f in gemini-pretool.sh gemini-session.sh; do assert_file "$repo/.bearing/hooks/$f" 755; done
assert_file "$repo/.gemini/settings.json" 644; assert_json "$repo/.gemini/settings.json"
assert_file "$repo/GEMINI.md" 644
nex="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["tools"]["exclude"]))' "$repo/.gemini/settings.json")"
assert_eq 1 "$([ "$nex" -ge 80 ] && echo 1)" "gemini exclude derived from the verb table (has $nex)"
assert_contains "$(cat "$repo/.gemini/settings.json")" "run_shell_command(git pu$H)"
adapter_denies "$repo/.bearing/hooks/gemini-pretool.sh" gemini/before-tool.json 2 '"decision":"deny"'
assert_contains "$GEN_OUT" "gemini: 2 of 2 adapters"
t_end

# ---- copilot
t_begin "copilot"
gen copilot
assert_vendored_guard
for f in copilot-pretool.sh copilot-session.sh; do assert_file "$repo/.bearing/hooks/$f" 755; done
assert_file "$repo/.github/hooks/bearing.json" 644; assert_json "$repo/.github/hooks/bearing.json"
assert_file "$repo/.github/copilot-instructions.md" 644
assert_file "$repo/.github/instructions/brg-database.instructions.md" 644
assert_file "$repo/.bearing/copilot-deny-tools.txt" 644
assert_contains "$(cat "$repo/.bearing/copilot-deny-tools.txt")" "--deny-tool 'shell(git pu$H)'"
assert_contains "$(sed -n 2p "$repo/.github/instructions/brg-testing.instructions.md")" 'applyTo: "**/*.test.ts,' "copilot applyTo"
adapter_denies "$repo/.bearing/hooks/copilot-pretool.sh" copilot/pre-tool-use.json 2 '"permissionDecision":"deny"'
# The fixture above sends toolArgs as an object (the hooks docs); Copilot CLI
# may send it as a JSON string. Both shapes deny the blocked command and allow
# an ordinary one; a toolArgs string that is not JSON is refused.
TOOLARGS_STRING='{"timestamp":1,"toolName":"bash","toolArgs":"{\"command\":\"__BLOCKED__\",\"description\":\"x\"}"}'
T_IN="$(printf '%s' "$TOOLARGS_STRING" | sed "s|__BLOCKED__|$BLOCKED|g")"; assert_exit 2 bash "$repo/.bearing/hooks/copilot-pretool.sh"
assert_contains "$T_OUT" "blocked 'git pu$H'" "toolArgs as a JSON string is parsed"
T_IN='{"toolName":"bash","toolArgs":{"command":"make check"}}'; assert_exit 0 bash "$repo/.bearing/hooks/copilot-pretool.sh"
T_IN='{"toolName":"bash","toolArgs":"{\"command\":\"make check\"}"}'; assert_exit 0 bash "$repo/.bearing/hooks/copilot-pretool.sh"
T_IN='{"toolName":"bash","toolArgs":"make check"}'; assert_exit 2 bash "$repo/.bearing/hooks/copilot-pretool.sh"
assert_contains "$T_OUT" "could not read the command" "a toolArgs string that is not JSON is refused"
assert_contains "$GEN_OUT" "copilot: 2 of 2 adapters wired, hook format unverified"
t_end

# ---- opencode
t_begin "opencode"
gen opencode
assert_vendored_guard
assert_file "$repo/.opencode/plugins/brg-guard.js" 644
assert_file "$repo/opencode.json" 644; assert_json "$repo/opencode.json"
assert_contains "$(cat "$repo/opencode.json")" "\"git pu$H*\": \"deny\""
if command -v node >/dev/null 2>&1; then
  assert_exit 0 node --check "$repo/.opencode/plugins/brg-guard.js"
  cp "$repo/.opencode/plugins/brg-guard.js" "$repo/.opencode/plugins/brg-guard.mjs"
  runner="$repo/.opencode/plugins/run-test.mjs"
  cat > "$runner" <<'EOF'
import { BearingGuard } from "./brg-guard.mjs";
const h = await BearingGuard();
const cmd = process.argv[2];
try { await h["tool.execute.before"]({ tool: "bash" }, { args: { command: cmd } }); console.log("ALLOWED"); }
catch (e) { console.log("DENIED " + String(e.message).trim()); }
EOF
  other="$(tmpdir)"
  assert_exit 0 bash -c "cd '$other' && node '$runner' 'git pu$H'"
  assert_contains "$T_OUT" "DENIED Bearing blocked 'git pu$H'" "plugin denies from another cwd (root from import.meta.url)"
  assert_exit 0 bash -c "cd '$other' && node '$runner' 'make check'"
  assert_contains "$T_OUT" "ALLOWED"
  assert_exit 0 bash -c "cd '$other' && node '$runner' ''"
  assert_contains "$T_OUT" "DENIED brg-guard: could not read the command" "empty command refused by the plugin"
  rm -f "$repo/.opencode/plugins/brg-guard.mjs" "$runner"
fi
assert_contains "$GEN_OUT" "opencode: 1 of 1 adapters"
t_end

# ---- windsurf
t_begin "windsurf"
gen windsurf
assert_vendored_guard
assert_file "$repo/.bearing/hooks/windsurf-run.sh" 755
assert_file "$repo/.devin/hooks.json" 644; assert_json "$repo/.devin/hooks.json"
assert_file "$repo/.devin/rules/brg-agents.md" 644
assert_file "$repo/.devin/rules/brg-testing.md" 644
assert_file "$repo/.windsurfrules" 644
adapter_denies "$repo/.bearing/hooks/windsurf-run.sh" windsurf/pre-run-command.json 2
assert_contains "$GEN_OUT" "windsurf: 1 of 1 adapters"
t_end

# ---- cline
t_begin "cline"
gen cline
assert_vendored_guard
assert_file "$repo/.clinerules/hooks/PreToolUse" 755
assert_file "$repo/.clinerules/bearing.md" 644
assert_file "$repo/.clinerules/brg-database.md" 644
assert_contains "$(sed -n 2p "$repo/.clinerules/brg-database.md")" 'paths: ["**/migrations/**", "**/migration/**"' "cline paths list"
adapter_denies "$repo/.clinerules/hooks/PreToolUse" cline/pre-tool-use.json 0 '"cancel":true'
T_IN='{"preToolUse":{"toolName":"read_file","parameters":{"path":"x"}}}'; assert_exit 0 bash "$repo/.clinerules/hooks/PreToolUse"
assert_eq "" "$T_OUT" "cline ignores other tools"
assert_contains "$GEN_OUT" "cline: 1 of 1 adapters"
t_end

# ---- zed
t_begin "zed"
gen zed
assert_file "$repo/.zed/settings.json" 644; assert_json "$repo/.zed/settings.json"
assert_file "$repo/.rules" 644
npat="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["agent"]["tool_permissions"]["tools"]["terminal"]["always_deny"]))' "$repo/.zed/settings.json")"
assert_eq 1 "$([ "$npat" -ge 80 ] && echo 1)" "zed always_deny derived from the verb table (has $npat)"
assert_contains "$(cat "$repo/.zed/settings.json")" "\\\\bgit\\\\s+pu$H\\\\b"
assert_contains "$GEN_OUT" "zed: settings only, no adapters"
_t_count; [ -d "$repo/.bearing/hooks" ] && _t_fail "zed wrote adapters"
t_end

# ---- kiro
t_begin "kiro"
gen kiro
assert_vendored_guard
assert_file "$repo/.bearing/hooks/kiro-pretool.sh" 755
assert_file "$repo/.kiro/hooks/brg-guard.json" 644; assert_json "$repo/.kiro/hooks/brg-guard.json"
assert_file "$repo/.kiro/steering/bearing.md" 644
assert_file "$repo/.kiro/steering/brg-testing.md" 644
assert_file "$repo/.bearing/kiro-permissions.yaml" 644
assert_contains "$(cat "$repo/.bearing/kiro-permissions.yaml")" "match: \"git pu$H*\""
adapter_denies "$repo/.bearing/hooks/kiro-pretool.sh" kiro/pre-tool-use.json 2
assert_contains "$GEN_OUT" "kiro: 1 of 1 adapters"
t_end

# ---- all, idempotence, conflicts and the empty-globs warning
t_begin "all harnesses, second run keeps, edited file conflicts"
gen all
assert_contains "$GEN_OUT" "0 conflicts"
assert_contains "$GEN_OUT" "zed: settings only, no adapters"
assert_exit 0 bash "$KIT/bin/brg-harness" all --dir "$repo" --no-skills
assert_contains "$T_OUT" "0 written"
assert_contains "$T_OUT" "0 conflicts"
assert_contains "$T_OUT" "brg-harness: 9 harness(es) checked, 9 wired"
assert_contains "$T_OUT" "unverified: codex, copilot, opencode, windsurf, cline, kiro (hook format"
assert_contains "$T_OUT" "cursor: 5 of 5 adapters wired, codex"
assert_contains "$T_OUT" "gemini: 2 of 2 adapters wired, copilot"
printf '{}\n' > "$repo/.cursor/hooks.json"
assert_exit 1 bash "$KIT/bin/brg-harness" cursor --dir "$repo" --no-skills
assert_contains "$T_OUT" "conflict  .cursor/hooks.json (proposal at .cursor/hooks.json.bearing-new)"
assert_contains "$T_OUT" "cursor: 0 of 5 adapters referenced, NOT wired (conflict at .cursor/hooks.json.bearing-new;"
assert_contains "$T_OUT" ".cursor/hooks.json does not reference .bearing/hooks/cursor-shell.sh"
assert_contains "$T_OUT" "brg-harness: 1 harness(es) checked, 0 wired"
assert_contains "$T_OUT" "1 harness(es) not wired"
assert_not_contains "$T_OUT" "4 of 4 adapters" "a conflicted config never reports full wiring"
assert_file "$repo/.cursor/hooks.json.bearing-new" 644
# A config that references every adapter but has a proposal beside it is
# still a conflict: not wired until the .bearing-new is resolved.
cp "$repo/.cursor/hooks.json.bearing-new" "$repo/.cursor/hooks.json"
assert_exit 1 bash "$KIT/bin/brg-harness" cursor --dir "$repo" --no-skills
assert_contains "$T_OUT" "cursor: 5 of 5 adapters referenced, NOT wired (conflict at .cursor/hooks.json.bearing-new)"
rm -f "$repo/.cursor/hooks.json.bearing-new"
assert_exit 0 bash "$KIT/bin/brg-harness" cursor --dir "$repo" --no-skills
assert_contains "$T_OUT" "cursor: 5 of 5 adapters wired"
# An OpenCode plugin replaced by the team's own does not call the guard.
printf 'export const Mine = async () => ({});\n' > "$repo/.opencode/plugins/brg-guard.js"
assert_exit 1 bash "$KIT/bin/brg-harness" opencode --dir "$repo" --no-skills
assert_contains "$T_OUT" "opencode: 0 of 1 adapters referenced, NOT wired"
mv "$repo/.opencode/plugins/brg-guard.js.bearing-new" "$repo/.opencode/plugins/brg-guard.js"
printf -- '---\ndescription: no paths here\n---\nbody\n' > "$repo/.claude/rules/nopaths.md"
assert_exit 0 bash "$KIT/bin/brg-harness" cursor --dir "$repo" --no-skills
assert_contains "$T_OUT" "warning: no paths: globs found in .claude/rules/nopaths.md"
printf -- '---\npaths: ["src/**", '"'"'lib/**'"'"']\n---\nbody\n' > "$repo/.claude/rules/inline.md"
printf -- '---\npaths:\n    - a/**\n    - '"'"'b/**'"'"'\n---\nbody\n' > "$repo/.claude/rules/indent.md"
assert_exit 0 bash "$KIT/bin/brg-harness" cursor --dir "$repo" --no-skills
assert_contains "$(sed -n 3p "$repo/.cursor/rules/brg-inline.mdc")" 'globs: src/**,lib/**' "inline paths list"
assert_contains "$(sed -n 3p "$repo/.cursor/rules/brg-indent.mdc")" 'globs: a/**,b/**' "indented, unquoted and single-quoted items"
assert_exit 2 bash "$KIT/bin/brg-harness" roo --dir "$repo" --no-skills
assert_contains "$T_OUT" "unknown harness: roo"
t_end

# ---- the env file is parsed, never sourced
t_begin "an env value with spaces is a value, not a command"
envd="$(tmpdir)"; marker="$envd/executed"
printf 'BEARING_KIT_REMOTE=https://example.invalid/kit.git touch %s\nBEARING_TRACKER=none\n' "$marker" > "$envd/bearing.env"
repo="$(tmpdir)"; git -C "$repo" init -q -b main
assert_exit 0 env -u BEARING_KIT_REMOTE BEARING_ENV="$envd/bearing.env" bash "$KIT/bin/brg-harness" zed --dir "$repo" --no-skills
_t_count; if [ -e "$marker" ]; then _t_fail "the env file was executed: $marker exists"; fi
assert_contains "$T_OUT" "brg-harness: 1 harness(es) checked, 1 wired"
t_end

# ---- the Claude Code adapters with every fixture
t_begin "claude adapters"
CH="$KIT/hooks/scripts"
T_IN="$(fixture claude/session-start.json)"; assert_exit 0 bash "$CH/session-start.sh"
T_IN="$(fixture claude/user-prompt-submit.json)"; assert_exit 0 bash "$CH/inject-task-id.sh"
T_IN="$(fixture claude/pre-tool-use.json)"; assert_exit 2 bash "$CH/block-publish.sh"
assert_contains "$T_OUT" "blocked 'git pu$H'"
T_IN="$(fixture claude/pre-tool-use-allow.json)"; assert_exit 0 bash "$CH/block-publish.sh"
assert_eq "" "$T_OUT"
T_IN="$(fixture claude/post-tool-use.json)"; assert_exit 0 bash "$CH/format-file.sh"
T_IN="$(fixture claude/stop.json)"; assert_exit 0 bash "$CH/stop-summary.sh"
t_end

# ---- hostile inputs deny on the adapters that read tool_input.command
t_begin "hostile fixtures deny, never allow"
gen codex
n=0
for fx in "$FIX"/hostile/*.json; do
  name="hostile/${fx##*/}"
  T_IN="$(fixture "$name")"; assert_exit 2 bash "$repo/.bearing/hooks/codex-pretool.sh"
  T_IN="$(fixture "$name")"; assert_exit 2 bash "$KIT/hooks/scripts/block-publish.sh"
  n=$((n+1))
done
assert_eq 6 "$n" "hostile fixtures exercised"
T_IN="$(fixture hostile/missing-key.json)"; assert_exit 2 bash "$repo/.bearing/hooks/codex-pretool.sh"
assert_contains "$T_OUT" "could not read the command"
T_IN="$(fixture hostile/invalid.json)"; assert_exit 2 bash "$KIT/hooks/scripts/block-publish.sh"
assert_contains "$T_OUT" "could not read the command"
T_IN="$(fixture hostile/decoy-command-key.json)"; assert_exit 2 bash "$repo/.bearing/hooks/codex-pretool.sh"
assert_contains "$T_OUT" "blocked 'git pu$H'"
t_end

# ---- without jq the adapters fail closed
t_begin "no jq: sentinel, warning, deny"
nojq="$(minimal_path bash git sed grep head tail tr wc cat dirname basename mktemp cmp mv rm mkdir ls awk cut sort uniq env printf)"
T_IN="$(fixture claude/pre-tool-use-allow.json)"
assert_exit 2 env PATH="$nojq" bash "$KIT/hooks/scripts/block-publish.sh"
assert_contains "$T_OUT" "jq is required by the hooks"
assert_contains "$T_OUT" "could not read the command"
assert_exit 2 env PATH="$nojq" bash "$repo/.bearing/hooks/codex-pretool.sh"
assert_contains "$T_OUT" "jq is required by the hooks"
T_IN="$(fixture claude/user-prompt-submit.json)"
assert_exit 0 env PATH="$nojq" bash "$KIT/hooks/scripts/inject-task-id.sh"
T_IN="$(fixture claude/post-tool-use.json)"
assert_exit 0 env PATH="$nojq" bash "$KIT/hooks/scripts/format-file.sh"
assert_exit 0 env PATH="$nojq" bash "$KIT/hooks/scripts/stop-summary.sh"
t_end

t_summary
