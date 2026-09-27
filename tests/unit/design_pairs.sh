#!/usr/bin/env bash
# tests/unit/design_pairs.sh: plugins/bearing/skills/design-critique/scripts/pairs.py
# computes text and field-edge contrast in light, data-theme dark and
# prefers-color-scheme dark from the CSS a page loads; passes a page where
# every pair holds, fails a muted token, a raw background that does not
# follow the theme (and names the background as the fault), a dark token set
# in one dark block only, a font nothing loads, a focus ring under 3:1 on the
# panel it is drawn on and an outline removed with nothing in its place;
# ratio recomputes a colour typed by hand; fails on zero pages.
set -u
. "$(dirname "$0")/../lib/assert.sh"
PR="$KIT/plugins/bearing/skills/design-critique/scripts/pairs.py"

# site <dir> <muted> <panel background> <extra dark-attr line>
site() {
  cat > "$1/t.css" <<EOF
:root { color-scheme: light dark; --bg: #ffffff; --text: #1f2430; --muted: $2; --edge: #767676; }
[data-theme="dark"] { --bg: #14171c; --text: #e6e8eb; --muted: #9aa3b2; --edge: #8a8f98; $4 }
@media (prefers-color-scheme: dark) { :root:not([data-theme="light"]) { --bg: #14171c; --text: #e6e8eb; --muted: #9aa3b2; --edge: #8a8f98; } }
EOF
  cat > "$1/p.html" <<EOF
<!doctype html><html lang="en"><head><link rel="stylesheet" href="t.css"><style>
body { background: var(--bg); color: var(--text); font-family: sans-serif; }
.m { color: var(--muted); }
.panel { background: $3; }
input { color: var(--text); background: var(--bg); border: 1px solid var(--edge); }
</style></head><body><main><h1>Invoices</h1><p class="m">Due 12 Oct</p>
<div class="panel"><p>Amount</p></div><label>Email <input value="a@b.example"></label></main></body></html>
EOF
}

t_begin "a page where every pair holds in all three contexts passes"
d="$(tmpdir)"; site "$d" "#5f6673" "var(--bg)" ""
assert_exit 0 python3 "$PR" "$d/p.html"
assert_contains "$T_OUT" "design-pairs: 1 pages, 5 text pairs, 1 controls and 0 focus rings x 3 contexts"
assert_contains "$T_OUT" "0 failing, 0 parity gaps, 0 raw colours, 0 fonts not loaded"
t_end

t_begin "a muted token under 4.5:1 fails in light only, with a passing fix"
d="$(tmpdir)"; site "$d" "#8b93a1" "var(--bg)" ""
assert_exit 1 python3 "$PR" "$d/p.html"
assert_contains "$T_OUT" "FAIL light: $d/p.html:6 <p.m> \"Due 12 Oct\" #8b93a1 on #ffffff = 3.09:1, needs 4.5"
assert_not_contains "$T_OUT" "FAIL dark-attr, dark-media: $d/p.html:6 <p.m>"
assert_contains "$T_OUT" "fix light: text #8b93a1 -> #"
t_end

t_begin "a raw panel background breaks dark and is named as the fault"
d="$(tmpdir)"; site "$d" "#5f6673" "#fff" ""
assert_exit 1 python3 "$PR" "$d/p.html"
assert_contains "$T_OUT" "FAIL dark-attr, dark-media: $d/p.html:7 <p> \"Amount\" #e6e8eb on #ffffff"
assert_contains "$T_OUT" "but fails on #ffffff: that background did not follow the tokens or the theme"
assert_contains "$T_OUT" "raw: $d/p.html:4: #fff"
t_end

t_begin "a dark token in one dark block only is a parity gap; an unloaded font is named"
d="$(tmpdir)"; site "$d" "#5f6673" "var(--bg)" "--ring: #f59e0b;"
sed -i.bak 's/font-family: sans-serif/font-family: "IBM Plex Sans", sans-serif/' "$d/p.html"; rm "$d/p.html.bak"
assert_exit 1 python3 "$PR" "$d/p.html"
assert_contains "$T_OUT" "parity: $d/t.css: --ring is set for data-theme dark but not under prefers-color-scheme dark"
assert_contains "$T_OUT" "font: ibm plex sans is asked for by p.html but no @font-face or font link loads it"
t_end

t_begin "an amber ring passes on the page and fails on the grey panel; a removed outline is named"
d="$(tmpdir)"; site "$d" "#5f6673" "#f6f7f9" ""
python3 - "$d/p.html" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace("</style>", "button:focus-visible { outline: 2px solid #d97706; outline-offset: 2px; }\ninput:focus { outline: none; }\n</style>")
s = s.replace("<p>Amount</p>", "<p>Amount</p><button>Pay</button>")
open(p, "w").write(s)
PY
assert_exit 1 python3 "$PR" "$d/p.html"
assert_contains "$T_OUT" "focus ring vs surround\" #d97706 on #f6f7f9 = 2.97:1, needs 3"
assert_not_contains "$T_OUT" "#d97706 on #ffffff"
assert_contains "$T_OUT" "fix light: focus ring #d97706 -> #"
assert_contains "$T_OUT" "outline removed on focus with no box-shadow or outline in its place"
assert_contains "$T_OUT" "and 2 focus rings x 3 contexts"
t_end

t_begin "ratio recomputes a hand-typed pair on each background"
assert_exit 0 python3 "$PR" ratio "#1f2430" "#f6f7f9" "#ffffff"
assert_contains "$T_OUT" "ratio: #1f2430 on #f6f7f9 = 14.48:1"
assert_contains "$T_OUT" "ratio: #1f2430 on #ffffff = 15.52:1"
assert_exit 1 python3 "$PR" ratio "#1f2430"
assert_exit 1 python3 "$PR" ratio "#1f2430" "notacolour"
t_end

t_begin "zero pages fail"
assert_exit 1 python3 "$PR"
assert_contains "$T_OUT" "0 pages given, nothing checked"
t_end

t_summary
