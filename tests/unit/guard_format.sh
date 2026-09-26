#!/usr/bin/env bash
# tests/unit/guard_format.sh: brg-guard format dispatches each extension to
# the right formatter (stubs on a fake PATH record what was called) and
# prints a note, exit 0, when the formatter is not installed.
set -u
. "$(dirname "$0")/../lib/assert.sh"

repo="$(tmpdir)"
git -C "$repo" init -q
log="$repo/format.log"
stubs="$(tmpdir)"
for tool in gofmt prettier ruff ktlint swiftformat terraform shfmt; do
  printf '#!/usr/bin/env bash\necho "%s $*" >> "%s"\n' "$tool" "$log" > "$stubs/$tool"
  chmod 755 "$stubs/$tool"
done
base="$(minimal_path bash git sed grep head tail tr wc cat dirname basename mktemp cmp mv rm mkdir ls awk cut sort uniq env printf)"

fmt_with() { # fmt_with <PATH> <file>: run the format subcommand from inside the repo
  ( cd "$repo" && PATH="$1" bash "$GUARD" format "$2" )
}

t_begin "each extension dispatches to its formatter"
n=0
for pair in "main.go:gofmt -w" "app.ts:prettier --log-level silent --write" "app.tsx:prettier" "a.js:prettier" "a.jsx:prettier" "a.json:prettier" "a.css:prettier" "a.md:prettier" "a.yml:prettier" "a.yaml:prettier" "a.py:ruff format --quiet" "a.kt:ktlint -F" "a.kts:ktlint -F" "a.swift:swiftformat --quiet" "a.tf:terraform fmt" "a.tfvars:terraform fmt" "a.sh:shfmt -w -i 2"; do
  f="${pair%%:*}"; want="${pair#*:}"
  : > "$repo/$f"; : > "$log"
  T_IN=''; assert_exit 0 fmt_with "$stubs:$base" "$repo/$f"
  assert_contains "$(cat "$log")" "$want" "$f dispatch"
  assert_contains "$(cat "$log")" "$repo/$f" "$f path passed"
  assert_contains "$T_OUT" "formatted $f" "$f note"
  n=$((n+1))
done
assert_eq 17 "$n" "extensions exercised"
t_end

t_begin "unknown extension does nothing"
: > "$repo/notes.txt"; : > "$log"
assert_exit 0 fmt_with "$stubs:$base" "$repo/notes.txt"
assert_eq "" "$(cat "$log")" "no formatter called"
assert_eq "" "$T_OUT" "no output"
t_end

t_begin "missing formatter prints a note and exits 0"
: > "$log"
assert_exit 0 fmt_with "$base" "$repo/main.go"
assert_contains "$T_OUT" "gofmt not installed"
assert_exit 0 fmt_with "$base" "$repo/a.py"
assert_contains "$T_OUT" "ruff not installed"
assert_exit 0 fmt_with "$base" "$repo/app.ts"
assert_contains "$T_OUT" "prettier not installed"
assert_exit 0 fmt_with "$base" "$repo/a.sh"
assert_contains "$T_OUT" "shfmt not installed"
assert_eq "" "$(cat "$log")" "nothing was called"
t_end

t_begin "a failing formatter leaves the file and says so"
printf '#!/usr/bin/env bash\nexit 1\n' > "$stubs/gofmt"
assert_exit 0 fmt_with "$stubs:$base" "$repo/main.go"
assert_contains "$T_OUT" "gofmt failed on main.go (left as written)"
t_end

t_begin "missing file, empty argument and the sentinel exit 0 silently"
assert_exit 0 bash "$GUARD" format "$repo/does-not-exist.go"
assert_eq "" "$T_OUT"
assert_exit 0 bash "$GUARD" format ""
assert_exit 0 bash "$GUARD" format "__BRG_UNPARSED__"
assert_eq "" "$T_OUT"
t_end

t_summary
