#!/usr/bin/env bash
# tests/unit/claude_code_drift.sh: bin/claude-code-drift.py compares what the
# installed Claude Code offers (version, CLI flags, hook events and settings
# keys from the settings schema) with the surface recorded last time and with
# what Bearing uses. New features are listed; a flag or hook event Bearing
# uses that the CLI no longer offers fails the run. A stub claude and a local
# schema stand in for the real ones.
set -u
. "$(dirname "$0")/../lib/assert.sh"

d="$(tmpdir)"
cat > "$d/claude" <<'S'
#!/usr/bin/env bash
case "$1" in
  --version) echo "${STUB_VERSION:-2.1.300} (Claude Code)" ;;
  --help) cat <<H
Usage: claude [options]
  -p, --print                 print and exit
  --output-format <format>    output format
  --setting-sources <s>       sources
  --settings <file-or-json>   settings
  --permission-mode <mode>    mode
  --disallowedTools, --disallowed-tools <tools...>
  --allowedTools, --allowed-tools <tools...>
  --no-session-persistence    no persistence
  --plugin-dir <dir>          plugin
  --verbose                   verbose
  --model <model>             model
  --resume <id>               resume
${STUB_EXTRA_FLAG:-}
H
  ;;
esac
S
chmod 755 "$d/claude"
schema() {
  python3 - "$d/schema.json" "$@" <<'PY'
import json, sys
events = ["PreToolUse", "PostToolUse", "UserPromptSubmit", "Stop", "SessionStart", "SessionEnd", "PreCompact",
          "StopFailure", "PostToolUseFailure", "PermissionDenied", "SubagentStop"] + sys.argv[2:]
json.dump({"properties": {"hooks": {"properties": {e: {} for e in events}},
                          "permissions": {}, "sandbox": {"properties": {"enabled": {}, "network": {}}}, "model": {}}},
          open(sys.argv[1], "w"))
PY
}
schema
surface="$d/surface.json"
drift() { BRG_CLAUDE="$d/claude" python3 "$KIT/bin/claude-code-drift.py" --schema "$d/schema.json" --surface "$surface" "$@"; }

t_begin "no recorded surface: it says so, lists what it read, and fails until recorded"
assert_exit 1 drift
assert_contains "$T_OUT" "no recorded surface"
assert_contains "$T_OUT" "claude-code-drift: 2.1.300"
t_end

t_begin "--record writes the surface and passes"
assert_exit 0 drift --record
assert_file "$surface"
assert_contains "$(cat "$surface")" '"version": "2.1.300"'
assert_contains "$(cat "$surface")" '"--output-format"'
t_end

t_begin "nothing new since the record passes and counts what it compared"
assert_exit 0 drift
assert_contains "$T_OUT" "0 new, 0 gone"
assert_contains "$T_OUT" "flags"
t_end

t_begin "a new flag and a new hook event are listed as new"
schema TaskCompleted
STUB_VERSION=2.1.310 STUB_EXTRA_FLAG="  --max-budget-usd <n>   budget" assert_exit 0 drift
assert_contains "$T_OUT" "2.1.300 -> 2.1.310"
assert_contains "$T_OUT" "new flag: --max-budget-usd"
assert_contains "$T_OUT" "new hook event: TaskCompleted"
t_end

t_begin "a hook event Bearing uses that the schema dropped fails the run"
python3 - "$d/schema.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1])); s["properties"]["hooks"]["properties"].pop("PreCompact")
json.dump(s, open(sys.argv[1], "w"))
PY
assert_exit 1 drift
assert_contains "$T_OUT" "gone but used: hook event PreCompact"
t_end

t_begin "a CLI flag the eval scripts pass that the CLI dropped fails the run"
schema
python3 - "$d/claude" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read().replace("  --no-session-persistence    no persistence\n", ""); open(p, "w").write(s)
PY
assert_exit 1 drift
assert_contains "$T_OUT" "gone but used: flag --no-session-persistence"
t_end

t_begin "a schema that cannot be read fails instead of passing on half the surface"
assert_exit 1 env BRG_CLAUDE="$d/claude" python3 "$KIT/bin/claude-code-drift.py" --schema "$d/nope.json" --surface "$surface"
assert_contains "$T_OUT" "nope.json"
t_end

t_summary
