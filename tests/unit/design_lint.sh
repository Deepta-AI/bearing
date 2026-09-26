#!/usr/bin/env bash
# tests/unit/design_lint.sh: skills/design-system/templates/design-lint.sh,
# the lint make check runs over a UI. A clean feature passes with its counts;
# a hardcoded colour, an arbitrary text size, a raw <table>/<button>/<input>
# where src/components/ui has the component, and a one-off font family each
# fail with the file and line; src/components/ui itself is exempt from the
# raw-element rule; an allowance lets a counted debt pass; zero files fail.
set -u
. "$(dirname "$0")/../lib/assert.sh"
LINT="$KIT/skills/design-system/templates/design-lint.sh"

repo() { # a React src tree with one clean feature file
  local d; d="$(tmpdir)"
  mkdir -p "$d/src/features/runs" "$d/src/components/ui"
  cat > "$d/src/features/runs/RunsTable.tsx" <<'TSX'
import { Table, TableBody } from "@/components/ui/table";
export function RunsTable() {
  return <Table className="text-sm"><TableBody /></Table>;
}
TSX
  printf 'export function Button() { return <button className="h-9" />; }\n' > "$d/src/components/ui/button.tsx"
  printf '%s' "$d"
}
lint() { (cd "$1" && shift && env "$@" bash "$LINT"); }

t_begin "a feature built from the component library passes, with its counts"
d="$(repo)"
assert_exit 0 lint "$d"
assert_contains "$T_OUT" "design-lint: 0 colours, 0 spacing, 0 font sizes, 0 shadows, 0 raw elements, 0 font families"
assert_contains "$T_OUT" "design-lint: passed"
t_end

t_begin "raw table and button in feature code fail; the ui folder is exempt"
d="$(repo)"
printf 'export const T = () => <table><tbody /></table>;\nexport const B = () => <button type="button">Go</button>;\n' > "$d/src/features/runs/Raw.tsx"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "raw elements where src/components/ui has the component: 2 hits"
assert_contains "$T_OUT" "src/features/runs/Raw.tsx:1:"
assert_not_contains "$T_OUT" "src/components/ui/button.tsx"
t_end

t_begin "a one-off font family fails in CSS, a style object and a class"
d="$(repo)"
printf '.x { font-family: "Comic Neue", cursive; }\n' > "$d/src/features/runs/x.css"
printf 'export const S = () => <p style={{ fontFamily: "Georgia" }}>x</p>;\nexport const T = () => <p className="font-[Archivo]">x</p>;\n' > "$d/src/features/runs/S.tsx"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "one-off font families: 3 hits"
t_end

t_begin "hardcoded colours and arbitrary text sizes still fail"
d="$(repo)"
printf 'export const C = () => <p className="text-[13px]" style={{ color: "#ff0000" }}>x</p>;\n' > "$d/src/features/runs/C.tsx"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "hardcoded colours: 1 hits"
assert_contains "$T_OUT" "off-scale font sizes: 1 hits"
t_end

t_begin "an allowance lets a counted debt pass"
d="$(repo)"
printf 'export const B = () => <button type="button">Go</button>;\n' > "$d/src/features/runs/Raw.tsx"
assert_exit 0 lint "$d" ALLOW_RAW=1
assert_contains "$T_OUT" "(allowance 0/0/0/0/1/0)"
t_end

t_begin "zero files fail"
d="$(tmpdir)"; mkdir -p "$d/src"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "design-lint: 0 files under"
t_end

t_summary
