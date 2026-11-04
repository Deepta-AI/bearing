#!/usr/bin/env bash
# tests/unit/harness_live.sh: bin/harness-live.sh against stub CLIs. Each
# stub plays its harness: it sends every shell command to the adapter
# brg-harness generated, with that harness's payload, and runs the command
# only when the adapter allows it (Codex and Gemini deny with exit 2, Cursor
# with {"permission":"deny"}). Three faithful stubs pass; a stub that runs
# commands without asking any hook fails, the push reaching the remote; a
# harness whose CLI is missing is skipped, and zero harnesses run is a
# failure, never a pass.
set -u
. "$(dirname "$0")/../lib/assert.sh"
LIVE="$KIT/bin/harness-live.sh"
stubs="$(tmpdir)"
# The kept folder of a failed run lands here and goes with the test's own.
TMPDIR="$(tmpdir)"; export TMPDIR

# stub <harness>: a CLI that reads the numbered commands from its last
# argument and asks the harness's adapter about each one.
cat > "$stubs/agent" <<'EOF'
#!/usr/bin/env bash
h="$1"; shift
for prompt; do :; done # the last argument, bash 3.2 safe
printf '%s\n' "$prompt" | sed -n 's/^[0-9]) //p' | while IFS= read -r c; do
  case "$h" in
    codex)  p="$(jq -nc --arg c "$c" '{hook_event_name: "PreToolUse", tool_name: "Bash", tool_input: {command: $c}}')"
            printf '%s' "$p" | bash ./.bearing/hooks/codex-pretool.sh >/dev/null 2>&1; [ $? -eq 2 ] && { echo "blocked: $c"; continue; };;
    gemini) p="$(jq -nc --arg c "$c" '{hook_event_name: "BeforeTool", tool_name: "run_shell_command", tool_input: {command: $c}}')"
            printf '%s' "$p" | bash ./.bearing/hooks/gemini-pretool.sh >/dev/null 2>&1; [ $? -eq 2 ] && { echo "blocked: $c"; continue; };;
    cursor) p="$(jq -nc --arg c "$c" --arg d "$PWD" '{hook_event_name: "beforeShellExecution", command: $c, cwd: $d}')"
            v="$(printf '%s' "$p" | bash ./.bearing/hooks/cursor-shell.sh 2>/dev/null | jq -r '.permission // empty')"
            [ "$v" = deny ] && { echo "blocked: $c"; continue; };;
    hookless) ;;
  esac
  bash -c "$c" && echo "ran: $c"
done
EOF
chmod 755 "$stubs/agent"
for h in codex cursor gemini hookless; do printf '#!/usr/bin/env bash\nexec "%s/agent" %s "$@"\n' "$stubs" "$h" > "$stubs/$h-cli"; chmod 755 "$stubs/$h-cli"; done

t_begin "three faithful harnesses: the guard fires, git push is refused, the harmless command runs"
assert_exit 0 env BRG_LIVE_CMD_CODEX="$stubs/codex-cli exec" BRG_LIVE_CMD_CURSOR="$stubs/cursor-cli -p" BRG_LIVE_CMD_GEMINI="$stubs/gemini-cli -p" bash "$LIVE"
for h in codex cursor gemini; do
  assert_contains "$T_OUT" "$h: pass (guard fired" "$h"
done
assert_contains "$T_OUT" "harness-live: 3 run, 3 passed, 0 skipped"
assert_not_contains "$T_OUT" "kept" "a clean run leaves nothing behind"
t_end

t_begin "a harness that never asks the hook fails, and its folder is kept"
assert_exit 1 env BRG_LIVE_CMD_CODEX="$stubs/hookless-cli exec" bash "$LIVE" --only codex
assert_contains "$T_OUT" "codex: FAIL"
assert_contains "$T_OUT" "no guard line in gates.log"
assert_contains "$T_OUT" "the push reached the remote"
assert_contains "$T_OUT" "harness-live: 1 run, 0 passed, 0 skipped"
kept="$(printf '%s\n' "$T_OUT" | sed -n 's/^harness-live: kept //p')"
assert_eq 1 "$([ -d "$kept" ] && echo 1)" "kept folder exists"
assert_file "$kept/codex.out"
t_end

t_begin "a missing CLI is skipped, and zero harnesses run is a failure"
assert_exit 1 env BRG_LIVE_CMD_CURSOR="brg-no-such-cli -p" bash "$LIVE" --only cursor
assert_contains "$T_OUT" "cursor: skipped (brg-no-such-cli not installed)"
assert_contains "$T_OUT" "harness-live: 0 run, 0 passed, 1 skipped"
t_end

t_begin "an unknown harness is a usage error"
assert_exit 2 bash "$LIVE" --only vim
t_end

t_summary
