#!/usr/bin/env bash
# tests/unit/design_contrast.sh: skills/design-system/scripts/contrast.py
# counts the pairs it checks in light and dark from tokens.json through
# themes's theme-lint.py, passes a system where every pair holds, and
# fails on a text pair below 4.5:1, on an undefined role, on a missing mode
# and on a missing tokens file (zero pairs checked).
set -u
. "$(dirname "$0")/../lib/assert.sh"
CT="$KIT/skills/design-system/scripts/contrast.py"

# tokens <path> [role=value ...]: light and dark role sets built from two
# greys; each extra argument overrides one light role.
tokens() {
  python3 - "$@" <<'PY'
import json, sys
path, overrides = sys.argv[1], sys.argv[2:]
back = ["bg", "bg-subtle", "surface", "surface-raised", "overlay", "accent-subtle",
        "success-subtle", "warning-subtle", "danger-subtle", "info-subtle", "selection",
        "on-accent", "on-success", "on-warning", "on-danger", "on-info"]
fore = ["text", "text-muted", "text-disabled", "link", "border", "border-strong", "accent",
        "accent-hover", "accent-active", "success", "warning", "danger", "info", "focus"]
def mode(light):
    b, f = ("oklch(0.98 0 0)", "oklch(0.25 0 0)") if light else ("oklch(0.2 0 0)", "oklch(0.95 0 0)")
    return {**{r: b for r in back}, **{r: f for r in fore}}
t = {"meta": {"name": "x", "version": 1, "source": "brief"},
     "color": {"primitives": {}, "roles": {"light": mode(True), "dark": mode(False)}}}
for o in overrides:
    k, v = o.split("=", 1)
    if k.startswith("-"):
        roles = t["color"]["roles"]
        (roles if k[1:] in ("light", "dark") else roles["light"]).pop(k[1:])
    else:
        t["color"]["roles"]["light"][k] = v
json.dump(t, open(path, "w"))
PY
}

t_begin "a system where every pair holds passes, with counts per mode"
d="$(tmpdir)"; tokens "$d/tokens.json"
assert_exit 0 python3 "$CT" --tokens "$d/tokens.json"
assert_contains "$T_OUT" "contrast: 68 pairs checked (light 34, dark 34), 0 below minimum (must be 0), AAA body pairs: 8"
t_end

t_begin "muted text below 4.5:1 fails and is named"
d="$(tmpdir)"; tokens "$d/tokens.json" "text-muted=oklch(0.8 0 0)"
assert_exit 1 python3 "$CT" --tokens "$d/tokens.json"
assert_contains "$T_OUT" "light: text-muted on bg is"
assert_contains "$T_OUT" "3 below minimum (must be 0)"
t_end

t_begin "an undefined role and a missing mode fail"
d="$(tmpdir)"; tokens "$d/tokens.json" "-focus=x"
assert_exit 1 python3 "$CT" --tokens "$d/tokens.json"
assert_contains "$T_OUT" "light: role 'focus' undefined"
tokens "$d/tokens.json" "-dark=x"
assert_exit 1 python3 "$CT" --tokens "$d/tokens.json"
assert_contains "$T_OUT" "dark: mode missing from color.roles"
assert_contains "$T_OUT" "(light 34, dark 0)"
t_end

t_begin "a missing tokens file checks nothing and fails"
d="$(tmpdir)"
assert_exit 1 python3 "$CT" --tokens "$d/none.json"
assert_contains "$T_OUT" "0 pairs checked, nothing checked"
t_end

t_summary
