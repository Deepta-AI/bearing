#!/usr/bin/env bash
# tests/unit/lint_plugin_size.sh: bin/lint-plugin-size.py holds each plugin
# folder to the plugin directory's limits (under 512 files, no non-image file
# of 256 KiB or more) and fails when there is no plugin to check.
set -u
. "$(dirname "$0")/../lib/assert.sh"
LINT="$KIT/bin/lint-plugin-size.py"
# repo_with <dir>: a git repository holding one plugin manifest.
repo_with() { mkdir -p "$1/plugins/p/.claude-plugin"; printf '{"name": "p"}\n' > "$1/plugins/p/.claude-plugin/plugin.json"; git init -q "$1"; }

t_begin "no plugins: nothing checked is a failure"
d="$(tmpdir)"; git init -q "$d"; mkdir -p "$d/plugins"
assert_exit 1 python3 "$LINT" "$d"
assert_contains "$T_OUT" "0 plugins under plugins/, nothing checked"
t_end

t_begin "a small plugin passes with its count"
d="$(tmpdir)"; repo_with "$d"; printf 'x\n' > "$d/plugins/p/a.md"
assert_exit 0 python3 "$LINT" "$d"
assert_contains "$T_OUT" "lint-plugin-size: 1 plugins under 512 files and 256 KiB a file: p 2 files"
t_end

t_begin "512 files fail"
d="$(tmpdir)"; repo_with "$d"; mkdir -p "$d/plugins/p/many"
i=1; while [ "$i" -le 511 ]; do : > "$d/plugins/p/many/f$i.md"; i=$((i+1)); done
assert_exit 1 python3 "$LINT" "$d"
assert_contains "$T_OUT" "plugins/p has 512 files, the limit is under 512"
t_end

t_begin "a 256 KiB text file fails, a large image passes"
d="$(tmpdir)"; repo_with "$d"
head -c 262144 /dev/zero | tr '\0' 'a' > "$d/plugins/p/big.md"
head -c 400000 /dev/zero > "$d/plugins/p/shot.png"
assert_exit 1 python3 "$LINT" "$d"
assert_contains "$T_OUT" "plugins/p/big.md is 256 KiB"
assert_not_contains "$T_OUT" "shot.png"
t_end

t_summary
