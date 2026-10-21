#!/usr/bin/env bash
# tests/integration/plugin_split.sh: Bearing ships as four plugins (bearing,
# bearing-backend, bearing-apps, bearing-genai). plugins/bearing/bin/brg-kit-paths finds the siblings in the
# repository layout and in the Claude Code cache layout
# (cache/<marketplace>/<plugin>/<version>), and the bearing plugin installed
# alone scaffolds, adopts and reviews nothing it cannot find: every stack
# request names the plugin to install and writes nothing. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
P="$KIT/plugins"
VER="$(tr -d '[:space:]' < "$KIT/VERSION")"

t_begin "the repository layout: four skill roots, bearing first"
assert_exit 0 bash "$P/bearing/bin/brg-kit-paths"
assert_eq 4 "$(printf '%s\n' "$T_OUT" | grep -c '/skills$')" "skill roots"
assert_eq "$P/bearing/skills" "$(printf '%s\n' "$T_OUT" | head -1)" "bearing first"
assert_exit 0 bash "$P/bearing/bin/brg-kit-paths" --skill go
assert_eq "$P/bearing-backend/skills/go" "$T_OUT"
assert_exit 0 bash "$P/bearing/bin/brg-kit-paths" --skill react
assert_eq "$P/bearing-apps/skills/react" "$T_OUT"
assert_exit 0 bash "$P/bearing/bin/brg-kit-paths" --version
assert_eq "$VER" "$T_OUT" "the manifest version is VERSION"
assert_exit 0 bash "$P/bearing/bin/brg-kit-paths" --skill rag
assert_eq "$P/bearing-genai/skills/rag" "$T_OUT"
assert_exit 0 bash "$P/bearing/bin/brg-kit-paths" --owner model-routing
assert_eq "bearing-genai" "$T_OUT"
assert_eq 0 "$(ls -d "$P"/bearing/skills/rag "$P"/bearing/skills/llm-eval 2>/dev/null | wc -l | tr -d ' ')" "moved skills gone from bearing"
t_end

t_begin "every plugin stands alone: no stack skill reaches into the bearing plugin by plugin-root path"
n=0; bad=""
docs="$(find "$P/bearing-backend" "$P/bearing-apps" "$P/bearing-genai" -name '*.md' -not -path '*/templates/*')"
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n+1))
  grep -qE 'CLAUDE_PLUGIN_ROOT\}?/(bin|templates|agents|hooks)/' "$f" && bad="$bad ${f#"$KIT"/}"
  own="${f%%/skills/*}"
  for m in $(grep -oE 'CLAUDE_PLUGIN_ROOT\}?/skills/[A-Za-z0-9_./-]+' "$f"); do
    rel="${m#*CLAUDE_PLUGIN_ROOT}"; rel="${rel#\}}"
    [ -e "$own$rel" ] || bad="$bad ${f#"$KIT"/}"
  done
done <<EOF
$docs
EOF
assert_eq 1 "$([ "$n" -gt 10 ] && echo 1)" "stack skill documents examined ($n)"
assert_eq "" "$bad" "stack skill files that use a bearing path under their own plugin root"
t_end

t_begin "the cache layout: siblings found at the same version, a missing one named"
cache="$(tmpdir)/cache/bearing"
mkdir -p "$cache/bearing" "$cache/bearing-backend"
cp -R "$P/bearing" "$cache/bearing/$VER"
cp -R "$P/bearing-backend" "$cache/bearing-backend/0.0.1"
cp -R "$P/bearing-backend" "$cache/bearing-backend/$VER"
assert_exit 0 bash "$cache/bearing/$VER/bin/brg-kit-paths" --plugins
assert_contains "$T_OUT" "bearing-backend	$cache/bearing-backend/$VER"
assert_not_contains "$T_OUT" "bearing-apps"
assert_exit 1 bash "$cache/bearing/$VER/bin/brg-kit-paths" --skill react
assert_contains "$T_OUT" "/plugin install bearing-apps@bearing"
t_end

# The bearing plugin alone, as a user who installed only the required plugin.
solo="$(tmpdir)/solo"
cp -R "$P/bearing" "$solo"
t_begin "bearing alone: brg-kit-paths lists only its own skills"
assert_exit 0 bash "$solo/bin/brg-kit-paths"
assert_eq "$solo/skills" "$T_OUT"
assert_exit 1 bash "$solo/bin/brg-kit-paths" --skill rag
assert_contains "$T_OUT" "rag is in the bearing-genai plugin, which is not installed: /plugin install bearing-genai@bearing"
t_end

t_begin "bearing alone: brg-scaffold names the missing plugin and writes nothing"
for pair in go-api:bearing-backend python-cli:bearing-backend infra:bearing-backend react-web:bearing-apps next-app:bearing-apps ios:bearing-apps; do
  stack="${pair%%:*}"; plugin="${pair#*:}"; target="$(tmpdir)/new-$stack"
  assert_exit 2 env BEARING_ENV=/nonexistent bash "$solo/bin/brg-scaffold" "$stack" ProbeSolo --dir "$target"
  assert_contains "$T_OUT" "$stack is in the $plugin plugin, which is not installed: /plugin install $plugin@bearing"
  assert_contains "$T_OUT" "nothing written"
  assert_eq 0 "$([ -e "$target" ] && echo 1 || echo 0)" "no target directory for $stack"
done
assert_exit 2 env BEARING_ENV=/nonexistent bash "$solo/bin/brg-scaffold" cobol-api ProbeSolo --dir "$(tmpdir)/cobol"
assert_contains "$T_OUT" "unknown stack 'cobol-api'. Known: none (install bearing-backend@bearing or bearing-apps@bearing"
t_end

t_begin "bearing alone: brg-adopt names the missing plugin and changes nothing"
repo="$(tmpdir)/adopt"; git init -q "$repo"; printf 'module x\n' > "$repo/go.mod"
before="$(cd "$repo" && ls -A | sort | tr '\n' ' ')"
assert_exit 2 env BEARING_ENV=/nonexistent bash "$solo/bin/brg-adopt" --dir "$repo" --stack go-api
assert_contains "$T_OUT" "go-api is in the bearing-backend plugin, which is not installed: /plugin install bearing-backend@bearing"
assert_eq "$before" "$(cd "$repo" && ls -A | sort | tr '\n' ' ')" "repository files unchanged"
t_end

t_begin "bearing alone: brg-checklists keeps the universal and database lists and names what to install"
assert_exit 0 bash "$solo/bin/brg-checklists" --files a.go b.swift schema.sql
assert_contains "$T_OUT" "$solo/skills/branch-review/references/universal-checklist.md"
assert_contains "$T_OUT" "$solo/skills/database/references/review-checklist.md"
assert_contains "$T_OUT" "no checklist: go ios"
assert_contains "$T_OUT" "install bearing-backend: /plugin install bearing-backend@bearing"
assert_contains "$T_OUT" "install bearing-apps: /plugin install bearing-apps@bearing"
t_end

t_begin "upgraders get bearing-genai: upgrade-tools installs it when missing, INSTALL says four (I5)"
t="$(tr '\n' ' ' < "$KIT/plugins/bearing/skills/upgrade-tools/SKILL.md" | tr -s ' ')"
assert_contains "$t" "claude plugin install bearing-genai@<marketplace>"
assert_contains "$t" "references/console.md"
assert_contains "$t" "Unattended (\`BEARING_NONINTERACTIVE\` or \`BEARING_AUTOPILOT\` set to a value other than \`0\`): ask nothing and print the command"
assert_contains "$(sed -n '/^---$/,/^---$/p' "$KIT/plugins/bearing/skills/upgrade-tools/SKILL.md")" "AskUserQuestion"
t="$(tr '\n' ' ' < "$KIT/docs/INSTALL.md" | tr -s ' ')"
assert_contains "$t" "the four move in lockstep"
assert_not_contains "$t" "the three move in lockstep"
assert_not_contains "$(cat "$KIT/docs/superpowers/plans/2026-10-17-genai-pack.md")" "feat/GenAIPack"
t_end

t_summary
