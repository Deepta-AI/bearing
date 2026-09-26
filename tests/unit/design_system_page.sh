#!/usr/bin/env bash
# tests/unit/design_system_page.sh: plugins/bearing/skills/design-system/scripts/system_page.py
# writes the shared tokens.css from tokens.json (light on :root and
# [data-theme="light"], dark on [data-theme="dark"] and under
# prefers-color-scheme), builds design-system.html from the template with
# every component drawn in a light pane and a dark pane, cuts a component the
# contract lacks, and its check fails on a missing state specimen, a colour
# literal, a page without tokens.css, and a contract with zero components.
set -u
. "$(dirname "$0")/../lib/assert.sh"
SP="$KIT/plugins/bearing/skills/design-system/scripts/system_page.py"
COMP="$KIT/plugins/bearing/skills/design-system/templates/components.md"

tokens() {
  python3 - "$1" <<'PY'
import json, sys
back = ["bg", "bg-subtle", "surface", "surface-raised", "overlay", "accent-subtle",
        "success-subtle", "warning-subtle", "danger-subtle", "info-subtle", "selection",
        "on-accent", "on-success", "on-warning", "on-danger", "on-info"]
fore = ["text", "text-muted", "text-disabled", "link", "border", "border-strong", "accent",
        "accent-hover", "accent-active", "success", "warning", "danger", "info", "focus"]
def mode(light):
    b, f = ("oklch(0.98 0.01 200)", "oklch(0.25 0.02 200)") if light else ("oklch(0.2 0.01 200)", "oklch(0.95 0.01 200)")
    return {**{r: b for r in back}, **{r: f for r in fore}}
roles = {r: {"family": "body", "size": "md", "weight": "regular", "lineHeight": "body", "tracking": "none"}
         for r in ("display", "title", "body", "label", "code")}
t = {"meta": {"name": "Ledgerline", "version": 3, "source": "brief"},
     "color": {"primitives": {}, "roles": {"light": mode(True), "dark": mode(False)}},
     "font": {"families": {"display": "serif", "body": "sans-serif", "mono": "monospace"},
              "sizes": {"sm": 14, "md": 16, "lg": 24}, "weights": {"regular": 400, "bold": 600},
              "lineHeights": {"body": 1.5, "tight": 1.15}, "letterSpacing": {"none": "0"}, "roles": roles},
     "space": {"base": 8, "half": 4, "scale": {"1": 4, "2": 8, "3": 16}},
     "radius": {"control": 6, "container": 12, "overlay": 16, "full": 9999},
     "elevation": {"rule": "r", "levels": {"0": {"light": "none", "dark": "none"}, "3": {"light": "0 8px 24px oklch(0 0 0 / 0.2)", "dark": "none"}}},
     "motion": {"duration": {"fast": 150, "deliberate": 700}, "easing": {"standard": "ease"}, "stagger": 40},
     "focus": {"width": 2, "offset": 2, "role": "focus"}}
json.dump(t, open(sys.argv[1], "w"))
PY
}

t_begin "tokens-css writes both themes, scoped so a page can show them side by side"
d="$(tmpdir)"; tokens "$d/tokens.json"
assert_exit 0 python3 "$SP" tokens-css --tokens "$d/tokens.json" --out "$d/tokens.css"
assert_contains "$T_OUT" "(colour roles light 30, dark 30), 0 problems"
css="$(cat "$d/tokens.css")"
assert_contains "$css" ':root, [data-theme="light"] {'
assert_contains "$css" '[data-theme="dark"] {'
assert_contains "$css" ':root:not([data-theme="light"])'
assert_contains "$css" "--color-accent-subtle: #"
assert_contains "$css" "--color-accent-subtle: oklch(0.98 0.01 200);"
assert_contains "$css" "--space-3: 16px;"
assert_contains "$css" "--duration-fast: 0ms;"
assert_exit 1 python3 "$SP" tokens-css --tokens "$d/none.json" --out "$d/x.css"
assert_contains "$T_OUT" "0 custom properties, nothing written"
t_end

t_begin "build draws every component in every state in light and dark; check passes"
d="$(tmpdir)"; tokens "$d/tokens.json"; cp "$COMP" "$d/components.md"
python3 "$SP" tokens-css --tokens "$d/tokens.json" --out "$d/tokens.css" >/dev/null
assert_exit 0 python3 "$SP" build --tokens "$d/tokens.json" --components "$d/components.md" --out "$d/design-system.html"
assert_contains "$T_OUT" "build: 14 components drawn in light and dark, 0 cut (none)"
page="$(cat "$d/design-system.html")"
assert_not_contains "$page" "{{"
assert_contains "$page" '<td data-theme="dark"><span class="sw" style="background: var(--color-accent)">'
assert_exit 0 python3 "$SP" check --page "$d/design-system.html" --components "$d/components.md"
assert_contains "$T_OUT" "design-system: 14 components, 68 states, 136 specimens (light 68, dark 68), 0 missing, 0 hardcoded colours"
t_end

t_begin "a component the contract lacks is cut"
d="$(tmpdir)"; tokens "$d/tokens.json"
python3 - "$COMP" "$d/components.md" <<'PY'
import re, sys
s = open(sys.argv[1]).read()
open(sys.argv[2], "w").write(re.sub(r"^## Sheet\n.*?(?=^## )", "", s, flags=re.M | re.S))
PY
: > "$d/tokens.css"
assert_exit 0 python3 "$SP" build --tokens "$d/tokens.json" --components "$d/components.md" --out "$d/design-system.html"
assert_contains "$T_OUT" "13 components drawn in light and dark, 1 cut (Sheet)"
assert_exit 0 python3 "$SP" check --page "$d/design-system.html" --components "$d/components.md"
assert_contains "$T_OUT" "design-system: 13 components, 64 states"
t_end

t_begin "a missing dark specimen, a colour literal and a missing tokens.css fail"
d="$(tmpdir)"; tokens "$d/tokens.json"; cp "$COMP" "$d/components.md"
python3 "$SP" build --tokens "$d/tokens.json" --components "$d/components.md" --out "$d/design-system.html" >/dev/null
python3 - "$d/design-system.html" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
i = s.index('<div class="pane" data-theme="dark">')
j = s.index('data-state="loading"', i)
s = s[:j] + 'data-x="loading"' + s[j + len('data-state="loading"'):]
s = s.replace("</style>", ".bad { color: #ff0000; }\n</style>", 1)
open(p, "w").write(s)
PY
assert_exit 1 python3 "$SP" check --page "$d/design-system.html" --components "$d/components.md"
assert_contains "$T_OUT" 'Button: no data-state="loading" specimen in the dark pane'
assert_contains "$T_OUT" "1 colour literals outside tokens.css (first: #ff0000)"
assert_contains "$T_OUT" "tokens.css link tokens.css points at no file"
assert_contains "$T_OUT" "1 missing, 1 hardcoded colours"
t_end

t_begin "zero components and a missing page fail"
d="$(tmpdir)"; printf '# Components\n\n## Button\n\nNo states line.\n' > "$d/components.md"
: > "$d/design-system.html"
assert_exit 1 python3 "$SP" check --page "$d/design-system.html" --components "$d/components.md"
assert_contains "$T_OUT" '0 components with a "- States:" line'
assert_exit 1 python3 "$SP" check --page "$d/none.html" --components "$d/components.md"
assert_contains "$T_OUT" "0 components checked"
t_end

t_summary
