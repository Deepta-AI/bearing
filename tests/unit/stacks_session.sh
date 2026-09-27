#!/usr/bin/env bash
# tests/unit/stacks_session.sh: bin/brg-stacks finds each stack and where it
# lives from marker files up to three folders deep, and brg-guard session
# names the conventions skill to load for each (or the plugin to install).
set -u
. "$(dirname "$0")/../lib/assert.sh"
STACKS="$KIT/plugins/bearing/bin/brg-stacks"

repo="$(tmpdir)"
git -C "$repo" init -q -b main
mkdir -p "$repo/services/api" "$repo/services/worker" "$repo/web" "$repo/mobile" "$repo/infra/modules/db" \
  "$repo/analytics/dags" "$repo/admin" "$repo/node_modules/x" "$repo/a/b/c/d"
printf 'module x\n' > "$repo/services/api/go.mod"
printf '[project]\n' > "$repo/services/worker/pyproject.toml"
printf '[project]\n' > "$repo/analytics/pyproject.toml"
printf '{"dependencies": {"next": "15"}}\n' > "$repo/web/package.json"
printf '{"dependencies": {"fastify": "5"}}\n' > "$repo/admin/package.json"
printf '{"devDependencies": {"prettier": "3"}}\n' > "$repo/package.json"
printf 'name: m\n' > "$repo/mobile/pubspec.yaml"
: > "$repo/infra/main.tf"; : > "$repo/infra/modules/db/main.tf"
printf '{"dependencies": {"react": "19"}}\n' > "$repo/node_modules/x/package.json"
printf 'node_modules/\n' > "$repo/.gitignore"
printf 'module deep\n' > "$repo/a/b/c/d/go.mod"

t_begin "each stack once, where it lives; tooling-only package.json, ignored and too-deep files do not count"
assert_exit 0 bash "$STACKS" "$repo"
assert_contains "$T_OUT" "go	services/api"
assert_contains "$T_OUT" "python	services/worker"
assert_contains "$T_OUT" "data-pipeline	analytics"
assert_contains "$T_OUT" "nextjs	web"
assert_contains "$T_OUT" "node	admin"
assert_contains "$T_OUT" "flutter	mobile"
assert_contains "$T_OUT" "infra	infra"
assert_not_contains "$T_OUT" "infra/modules"
assert_not_contains "$T_OUT" "react	"
assert_not_contains "$T_OUT" "a/b/c/d"
assert_contains "$T_OUT" "stacks: data-pipeline flutter go infra nextjs node python"
t_end

t_begin "session names the skill for each stack"
assert_exit 0 bash -c "cd '$repo' && bash '$GUARD' session"
assert_contains "$T_OUT" "load its conventions skill first"
assert_contains "$T_OUT" "  go (services/api): bearing-backend:go"
assert_contains "$T_OUT" "  nextjs (web): bearing-apps:nextjs"
assert_contains "$T_OUT" "  infra (infra): bearing-backend:infra"
t_end

t_begin "a stack whose plugin is missing gets the install line"
assert_exit 0 bash -c "cd '$repo' && BEARING_PLUGIN_DIRS='$repo/none' bash '$GUARD' session"
assert_contains "$T_OUT" "  go (services/api): not installed, /plugin install bearing-backend@bearing"
t_end

t_begin "an empty repository examines nothing: brg-stacks fails, session stays quiet"
empty="$(tmpdir)"; git -C "$empty" init -q -b main
assert_exit 1 bash "$STACKS" "$empty"
assert_contains "$T_OUT" "0 marker files examined"
assert_exit 0 bash -c "cd '$empty' && bash '$GUARD' session"
assert_not_contains "$T_OUT" "Stacks in this repository"
t_end

t_summary
