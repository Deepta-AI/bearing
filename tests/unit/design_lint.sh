#!/usr/bin/env bash
# tests/unit/design_lint.sh: plugins/bearing/skills/design-system/templates/design-lint.sh,
# the lint make check runs over a UI. A clean feature passes with its counts;
# a hardcoded colour, an arbitrary text size, a raw <table>/<button>/<input>
# where src/components/ui has the component, and a one-off font family each
# fail with the file and line; src/components/ui itself is exempt from the
# raw-element rule. Comments, issue references and anchors are not colours; px
# written as strings in style objects are checked. Debt lives in a baseline per
# file and literal: a second copy of a baselined literal fails, a paid debt must
# leave the baseline, and --write-baseline never grows it. DESIGN_LINT_RULES
# limits the gate to the rules asked for; vendor/ and *.min.* are never scanned. It runs with sh and
# awk only (no bash, python3 or node, as on node:alpine), and zero files fail.
set -u
. "$(dirname "$0")/../lib/assert.sh"
LINT="$KIT/plugins/bearing/skills/design-system/templates/design-lint.sh"

repo() { # a React src tree with one clean feature file
  local d; d="$(tmpdir)"
  mkdir -p "$d/src/features/runs" "$d/src/components/ui" "$d/src/styles"
  cat > "$d/src/features/runs/RunsTable.tsx" <<'TSX'
import { Table, TableBody } from "@/components/ui/table";
export function RunsTable() {
  return <Table className="text-sm"><TableBody /></Table>;
}
TSX
  printf 'export function Button() { return <button className="h-9" />; }\n' > "$d/src/components/ui/button.tsx"
  printf ':root { --c: #ffffff; --space-1: 4px; --space-2: 8px; --space-3: 16px; --font-size-sm: 13px; --font-size-md: 15px; }\n' > "$d/src/styles/tokens.css"
  printf '%s' "$d"
}
lint() { (cd "$1" && shift && env "$@" sh "$LINT"); }
baseline() { (cd "$1" && sh "$LINT" --write-baseline); }
bb() { (cd "$1" && busybox sh "$LINT"); }

t_begin "a feature built from the component library passes, with its counts and scale source"
d="$(repo)"
assert_exit 0 lint "$d"
assert_contains "$T_OUT" "design-lint: 0 colours, 0 spacing, 0 font sizes, 0 shadows, 0 raw elements, 0 font families; 0 new"
assert_contains "$T_OUT" "scales from src/styles/tokens.css (space: 4 8 16; sizes: 13 15)"
assert_contains "$T_OUT" "design-lint: passed"
t_end

t_begin "raw table and button in feature code fail; the ui folder is exempt"
d="$(repo)"
printf 'export const T = () => <table><tbody /></table>;\nexport const B = () => <button type="button">Go</button>;\n' > "$d/src/features/runs/Raw.tsx"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "2 raw elements"
assert_contains "$T_OUT" "src/features/runs/Raw.tsx:1:"
assert_not_contains "$T_OUT" "src/components/ui/button.tsx"
t_end

t_begin "a one-off font family fails in CSS, a style object and a class"
d="$(repo)"
printf '.x { font-family: "Comic Neue", cursive; }\n' > "$d/src/features/runs/x.css"
printf 'export const S = () => <p style={{ fontFamily: "Georgia" }}>x</p>;\nexport const T = () => <p className="font-[Archivo]">x</p>;\n' > "$d/src/features/runs/S.tsx"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "3 font families"
t_end

t_begin "hardcoded colours and arbitrary text sizes fail; comments, issue refs and anchors do not"
d="$(repo)"
printf 'export const C = () => <p className="text-[13px]" style={{ color: "#ff0000" }}>x</p>;\n' > "$d/src/features/runs/C.tsx"
cat > "$d/src/features/runs/Quiet.jsx" <<'JSX'
// Was #1d5fd1 before the rebrand (see #123).
export function Quiet() {
  /* rgba(0, 0, 0, 0.5) lived here */
  if (window.location.hash === "#feed") document.getElementById("feed");
  return <a href="#fade" id="feed">x</a>;
}
JSX
printf '/* old accent #1d5fd1 */\n.q { color: var(--c); }\n' > "$d/src/features/runs/q.css"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "1 colours, 0 spacing, 1 font sizes"
assert_contains "$T_OUT" "src/features/runs/C.tsx:1: #ff0000"
t_end

t_begin "rgba, hsl and named colours count; hsl(var(--x)) does not"
d="$(repo)"
printf '.a { background: rgba(29, 95, 209, 0.06); border: 1px solid red; color: hsl(var(--c)); }\n' > "$d/src/features/runs/a.css"
printf 'export const t = { paid: "hsl(142 70%% 35%%)" };\n' > "$d/src/features/runs/t.js"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "3 colours"
t_end

t_begin "spacing off the token scale fails, including px in a style-object string"
d="$(repo)"
printf '.a { padding: 8px 20px; margin: 1.25rem; }\n' > "$d/src/features/runs/a.css"
printf 'export const S = () => <p style={{ padding: "0 8px", marginTop: 28, gap: "6px 16px" }}>x</p>;\n' > "$d/src/features/runs/S.jsx"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "4 spacing"
assert_contains "$T_OUT" "S.jsx:1: 6px"
assert_not_contains "$T_OUT" "S.jsx:1: 8px"
t_end

t_begin "a baseline keeps today's debt green and fails every new copy, even on the same line"
d="$(repo)"
printf 'export const S = () => <p style={{ color: "#d5dae1", marginTop: 28 }}>x</p>;\n' > "$d/src/features/runs/S.jsx"
assert_exit 1 lint "$d"
assert_exit 0 baseline "$d"
assert_contains "$T_OUT" "wrote scripts/design-lint.baseline with 2 keys"
assert_exit 0 lint "$d"
assert_contains "$T_OUT" "1 colours, 1 spacing"
printf 'export const S = () => <p style={{ color: "#d5dae1", borderColor: "#d5dae1", marginTop: 28 }}>x</p>;\n' > "$d/src/features/runs/S.jsx"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "NEW colour src/features/runs/S.jsx:1: #d5dae1"
assert_exit 1 baseline "$d"
assert_contains "$T_OUT" "not raised (2 > 1)"
t_end

t_begin "a paid debt must leave the baseline, and the baseline never gains a key"
d="$(repo)"
printf 'export const S = () => <p style={{ color: "#d5dae1", marginTop: 28 }}>x</p>;\n' > "$d/src/features/runs/S.jsx"
baseline "$d" >/dev/null
printf 'export const S = () => <p style={{ color: "var(--c)", marginTop: 28 }}>x</p>;\n' > "$d/src/features/runs/S.jsx"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "1 fixed but still baselined"
assert_exit 0 baseline "$d"
assert_exit 0 lint "$d"
printf '.n { color: #abcdef; }\n' > "$d/src/features/runs/n.css"
assert_exit 1 baseline "$d"
assert_contains "$T_OUT" "not added (new): colour src/features/runs/n.css #abcdef"
t_end

t_begin "runs with sh and awk alone: no bash, no python3, no node"
d="$(repo)"
mp="$(minimal_path sh awk grep find sort sed wc tr mktemp rm cat dirname mkdir env)"
printf '.x { color: #123456; }\n' > "$d/src/features/runs/x.css"
assert_exit 1 lint "$d" PATH="$mp"
assert_contains "$T_OUT" "1 colours"
assert_not_contains "$T_OUT" "not found"
if command -v busybox >/dev/null 2>&1; then
  assert_exit 1 bb "$d"
  assert_contains "$T_OUT" "1 colours"
fi
t_end

t_begin "DESIGN_LINT_RULES gates only the rules the team asked for"
d="$(repo)"
printf 'export const R = () => <button style={{ color: "#ff0000", boxShadow: "0 1px 2px #0003" }}>x</button>;\n' > "$d/src/features/runs/R.jsx"
assert_exit 0 lint "$d" DESIGN_LINT_RULES="spacing font-size"
assert_exit 0 lint "$d" DESIGN_LINT_RULES="shadow"
assert_contains "$T_OUT" "0 colours, 0 spacing, 0 font sizes, 0 shadows, 0 raw elements, 0 font families"
assert_contains "$T_OUT" "rules: shadow"
assert_exit 1 lint "$d" DESIGN_LINT_RULES="colour"
assert_contains "$T_OUT" "1 colours"
assert_contains "$T_OUT" "0 raw elements"
t_end

t_begin "vendored and minified third-party files are not scanned"
d="$(repo)"
mkdir -p "$d/src/vendor/datepicker"
printf '.dp { color: #3b82f6; padding: 7px; }\n' > "$d/src/vendor/datepicker/datepicker.css"
printf '.m{color:#ff0000}\n' > "$d/src/features/runs/lib.min.css"
assert_exit 0 lint "$d"
assert_contains "$T_OUT" "0 colours, 0 spacing"
t_end

t_begin "zero files fail"
d="$(tmpdir)"; mkdir -p "$d/src"
assert_exit 1 lint "$d"
assert_contains "$T_OUT" "design-lint: 0 files under"
t_end

t_summary
