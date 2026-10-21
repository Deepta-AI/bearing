#!/usr/bin/env bash
# tests/unit/guard_format.sh: brg-guard format dispatches each extension to
# the right formatter, taken only from the guard's fixed directories (here a
# copy of the guard whose fmt_dirs names a stub directory, the one seam), in
# a cleared environment; it prints a note, exit 0, when the formatter is not
# installed; and it runs prettier only when the prettier config that applies
# is data that loads no code.
set -u
. "$(dirname "$0")/../lib/assert.sh"

repo="$(tmpdir)"
git -C "$repo" init -q
log="$repo/format.log"
stubs="$(tmpdir)"
for tool in gofmt prettier ruff ktlint swiftformat terraform shfmt; do
  printf '#!/bin/sh\necho "%s $*" >> "%s"\n/usr/bin/env >> "%s.env"\n' "$tool" "$log" "$log" > "$stubs/$tool"
  chmod 755 "$stubs/$tool"
done
base="$(minimal_path bash git sed grep head tail tr wc cat dirname basename mktemp cmp mv rm mkdir ls awk cut sort uniq env printf jq python3)"
gb="$(tmpdir)"; cp "$GUARD" "$gb/brg-guard"
dirs_line="$(grep -n '^  printf .%s.n. /opt/homebrew/bin' "$GUARD" | cut -d: -f2-)"
replace_in "$gb/brg-guard" "$dirs_line" "  printf '%s\\n' '$stubs'"
G="$gb/brg-guard"

fmt_with() { # fmt_with <PATH> <file>: run the format subcommand from inside the repo
  ( cd "$repo" && PATH="$1" HOME="$repo/home" bash "$G" format "$2" )
}

t_begin "each extension dispatches to its formatter"
n=0
for pair in "main.go:gofmt -w" "app.ts:prettier --log-level silent --write" "app.tsx:prettier" "a.js:prettier" "a.jsx:prettier" "a.json:prettier" "a.css:prettier" "a.md:prettier" "a.yml:prettier" "a.yaml:prettier" "a.py:ruff format --quiet" "a.kt:ktlint -F" "a.kts:ktlint -F" "a.swift:swiftformat --quiet" "a.tf:terraform fmt" "a.tfvars:terraform fmt" "a.sh:shfmt -w -i 2"; do
  f="${pair%%:*}"; want="${pair#*:}"
  : > "$repo/$f"; : > "$log"
  T_IN=''; assert_exit 0 fmt_with "$base" "$repo/$f"
  assert_contains "$(cat "$log")" "$want" "$f dispatch"
  assert_contains "$(cat "$log")" "$repo/$f" "$f path passed"
  assert_contains "$T_OUT" "formatted $f" "$f note"
  n=$((n+1))
done
assert_eq 17 "$n" "extensions exercised"
t_end

t_begin "the formatter runs in a cleared environment with the fixed PATH"
: > "$log.env"
( cd "$repo" && BRG_LEAK=1 NODE_OPTIONS=--require=/x.js PYTHONPATH=/x PATH="$base" HOME="$repo/home" bash "$G" format "$repo/a.py" ) >/dev/null 2>&1
envs="$(cat "$log.env")"
assert_contains "$envs" "PATH=$stubs" "PATH is the fixed directories"
assert_not_contains "$envs" "BRG_LEAK" "an inherited variable is cleared"
assert_not_contains "$envs" "NODE_OPTIONS" "NODE_OPTIONS is cleared"
assert_not_contains "$envs" "PYTHONPATH" "PYTHONPATH is cleared"
assert_contains "$envs" "HOME=$repo/home" "HOME is kept"
t_end

t_begin "unknown extension does nothing"
: > "$repo/notes.txt"; : > "$log"
assert_exit 0 fmt_with "$base" "$repo/notes.txt"
assert_eq "" "$(cat "$log")" "no formatter called"
assert_eq "" "$T_OUT" "no output"
t_end

t_begin "missing formatter prints a note and exits 0"
: > "$log"
gb2="$(tmpdir)"; cp "$GUARD" "$gb2/brg-guard"; empty="$(tmpdir)"
replace_in "$gb2/brg-guard" "$dirs_line" "  printf '%s\\n' '$empty'"
nofmt() { ( cd "$repo" && PATH="$stubs:$base" HOME="$repo/home" bash "$gb2/brg-guard" format "$1" ); }
assert_exit 0 nofmt "$repo/main.go"
assert_contains "$T_OUT" "gofmt not installed" "a stub on PATH alone is not installed"
assert_exit 0 nofmt "$repo/a.py"
assert_contains "$T_OUT" "ruff not installed"
assert_exit 0 nofmt "$repo/app.ts"
assert_contains "$T_OUT" "prettier not installed"
assert_exit 0 nofmt "$repo/a.sh"
assert_contains "$T_OUT" "shfmt not installed"
assert_eq "" "$(cat "$log")" "nothing was called"
t_end

t_begin "prettier runs only under a config that loads no code"
: > "$repo/app.ts"
pr() { : > "$log"; fmt_with "$base" "$repo/app.ts" >/dev/null 2>&1; cat "$log"; }
cfg_case() { # cfg_case <file> <content> <ran|skipped>
  printf '%s\n' "$2" > "$repo/$1"
  if [ "$3" = ran ]; then assert_contains "$(pr)" "prettier" "$1 ($2): prettier runs"
  else assert_eq "" "$(pr)" "$1 ($2): prettier not run"; fi
  rm -f "$repo/$1"
}
assert_contains "$(pr)" "prettier" "no config: prettier runs"
cfg_case .prettierrc.json '{"semi": false, "singleQuote": true}' ran
cfg_case .prettierrc.json '{"overrides": [{"files": "*.json", "options": {"parser": "json5"}}]}' ran
cfg_case .prettierrc.json '{"$schema": "http://json.schemastore.org/prettierrc", "printWidth": 100, "trailingComma": "all", "overrides": [{"files": ["*.md"], "excludeFiles": "x.md", "options": {"proseWrap": "always"}}]}' ran
# Only JSON parsed as data, every key a plain formatting option: an escaped
# key decodes to plugins, so a text match is not enough.
cfg_case .prettierrc.json '{"\u0070lugins": ["./evil.js"]}' skipped
cfg_case .prettierrc.json '{"semi": false, "overrides": [{"files": "*.ts", "options": {"\u0070lugins": ["./evil.js"]}}]}' skipped
cfg_case .prettierrc.json '{"semi": false, "pluginSearchDirs": ["."]}' skipped
cfg_case .prettierrc.json '{"parser": "babel", "x": 1}' skipped
cfg_case .prettierrc.json '{"semi": false' skipped
cfg_case package.json '{"name": "x", "prettier": {"\u0070lugins": ["./evil.js"]}}' skipped
cfg_case .prettierrc 'semi: false' skipped
cfg_case .prettierrc '{"semi": false}' skipped
cfg_case .prettierrc.yaml 'semi: false' skipped
cfg_case .prettierrc.yml 'semi: false' skipped
cfg_case .prettierrc.toml 'semi = false' skipped
cfg_case .prettierrc.json5 '{semi: false}' skipped
cfg_case package.json '{"name": "x", "devDependencies": {"prettier": "^3.0.0"}}' ran
cfg_case package.json '{"name": "x", "prettier": {"semi": false}}' ran
cfg_case prettier.config.js 'module.exports = {}' skipped
cfg_case .prettierrc.mjs 'export default {}' skipped
cfg_case .prettierrc.ts 'export default {}' skipped
cfg_case .prettierrc.json '{"plugins": ["prettier-plugin-x"]}' skipped
cfg_case .prettierrc 'plugins: [./evil.js]' skipped
cfg_case .prettierrc.json '{"parser": "./parser.js"}' skipped
cfg_case .prettierrc.json '"@acme/prettier-config"' skipped
cfg_case package.json '{"name": "x", "prettier": "@acme/prettier-config"}' skipped
mkdir -p "$repo/web/src"; : > "$repo/web/src/app.ts"
printf 'module.exports = {}\n' > "$repo/web/prettier.config.cjs"
: > "$log"; T_IN=''; assert_exit 0 fmt_with "$base" "$repo/web/src/app.ts"
assert_eq "" "$(cat "$log")" "a JS config in a parent directory: not run"
assert_contains "$T_OUT" "prettier not run: the repository's prettier config is not .prettierrc.json"
printf '{"semi": false}\n' > "$repo/web/src/.prettierrc.json"
: > "$log"; fmt_with "$base" "$repo/web/src/app.ts" >/dev/null 2>&1
assert_contains "$(cat "$log")" "prettier" "the nearest config decides"
rm -rf "$repo/web"
t_end

t_begin "prettier is not run when a directory between the file and the root is a link"
# prettier looks for its config along the path it is given (src2, then the
# root, where a JS config waits); the check must walk that same path, not the
# link's target outside the repository.
out="$(tmpdir)"; mkdir -p "$out/inner"; : > "$out/app.ts"; : > "$out/inner/app.ts"
printf 'module.exports = {}\n' > "$repo/prettier.config.js"
ln -s "$out" "$repo/src2"
n=0
for f in src2/app.ts src2/inner/app.ts; do
  : > "$log"; T_IN=''; assert_exit 0 fmt_with "$base" "$repo/$f"
  assert_eq "" "$(cat "$log")" "$f: prettier not run"
  assert_contains "$T_OUT" "prettier not run" "$f: a note says so"
  n=$((n+1))
done
# a link inside the repository is refused too: prettier would still walk the given path
mkdir -p "$repo/real"; : > "$repo/real/app.ts"; ln -s "$repo/real" "$repo/alias"; rm -f "$repo/prettier.config.js"
: > "$log"; T_IN=''; assert_exit 0 fmt_with "$base" "$repo/alias/app.ts"
assert_eq "" "$(cat "$log")" "alias/app.ts: prettier not run"
n=$((n+1))
assert_eq 3 "$n" "linked paths checked"
# the same file through its real path still formats
: > "$log"; fmt_with "$base" "$repo/real/app.ts" >/dev/null 2>&1
assert_contains "$(cat "$log")" "prettier" "real/app.ts: prettier runs"
rm -f "$repo/alias" "$repo/src2" "$repo/real/app.ts"; rmdir "$repo/real"
t_end

t_begin "a failing formatter leaves the file and says so"
printf '#!/bin/sh\nexit 1\n' > "$stubs/gofmt"
assert_exit 0 fmt_with "$base" "$repo/main.go"
assert_contains "$T_OUT" "gofmt failed on main.go (left as written)"
t_end

t_begin "missing file, a link, empty argument and the sentinel exit 0 silently"
assert_exit 0 bash "$G" format "$repo/does-not-exist.go"
assert_eq "" "$T_OUT"
assert_exit 0 bash "$G" format ""
assert_exit 0 bash "$G" format "__BRG_UNPARSED__"
assert_eq "" "$T_OUT"
ln -s "$repo/main.go" "$repo/link.go"; : > "$log"
assert_exit 0 fmt_with "$base" "$repo/link.go"
assert_eq "" "$(cat "$log")" "a link is not formatted"
t_end

t_summary
