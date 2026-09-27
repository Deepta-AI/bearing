#!/usr/bin/env bash
# tests/unit/theme_lint_css.sh: plugins/bearing/skills/themes/templates/theme-lint.py
# --css reads light from :root, dark from the prefers-color-scheme media
# block and a tenant block laid over light; resolves var() references;
# counts themes and pairs; names a failing pair; checks an extra --pair;
# skips @media print; and fails on a stylesheet with no theme blocks.
set -u
. "$(dirname "$0")/../lib/assert.sh"
TL="$KIT/plugins/bearing/skills/themes/templates/theme-lint.py"

css() {
  cat > "$1" <<'CSS'
/* palette */
:root {
  --grey-0: #ffffff;
  --color-bg: var(--grey-0);
  --color-surface: #fafafa;
  --color-text: #1a1a1a;
  --color-text-muted: rgb(85, 85, 85);
  --color-badge-text: #1a1a1a;
  --color-badge-bg: #eeeeee;
}
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg: #111111;
    --color-surface: oklch(0.22 0 0);
    --color-text: #f2f2f2;
    --color-text-muted: #b0b0b0;
  }
}
[data-tenant="acme"] {
  --color-text-muted: MUTED;
}
@media print {
  :root { --color-text: #cccccc; }
}
CSS
}

t_begin "light, dark and a tenant theme pass, with counts"
d="$(tmpdir)"; css "$d/t.css"; sed -i.bak 's/MUTED/#444444/' "$d/t.css"
assert_exit 0 python3 "$TL" --css "$d/t.css"
assert_contains "$T_OUT" "light: 6 colour roles, 4 pairs, 0 failures"
assert_contains "$T_OUT" "dark: 6 colour roles, 4 pairs, 0 failures"
assert_contains "$T_OUT" "acme: 6 colour roles, 4 pairs, 0 failures"
assert_contains "$T_OUT" "theme-lint: 3 themes, 12 pairs checked, 0 failures"
t_end

t_begin "a tenant value below 4.5:1 fails and is named"
d="$(tmpdir)"; css "$d/t.css"; sed -i.bak 's/MUTED/#aaaaaa/' "$d/t.css"
assert_exit 1 python3 "$TL" --css "$d/t.css"
assert_contains "$T_OUT" "acme: 6 colour roles, 4 pairs, 2 failures"
assert_contains "$T_OUT" "text-muted #aaaaaa on bg #ffffff is"
t_end

t_begin "an extra --pair is checked, and one naming a missing role fails"
d="$(tmpdir)"; css "$d/t.css"; sed -i.bak 's/MUTED/#444444/' "$d/t.css"
assert_exit 0 python3 "$TL" --css "$d/t.css" --pair badge-text:badge-bg
assert_contains "$T_OUT" "theme-lint: 3 themes, 15 pairs checked, 0 failures"
assert_exit 1 python3 "$TL" --css "$d/t.css" --pair badge-text:badge-border
assert_contains "$T_OUT" "pair badge-text:badge-border: a role is not defined in this theme"
t_end

t_begin "a stylesheet with no theme blocks checks nothing and fails"
d="$(tmpdir)"; printf '.btn { color: #000; }\n' > "$d/none.css"
assert_exit 1 python3 "$TL" --css "$d/none.css"
assert_contains "$T_OUT" "theme-lint: 0 themes, 0 pairs checked"
assert_contains "$T_OUT" "nothing checked"
t_end

t_summary
