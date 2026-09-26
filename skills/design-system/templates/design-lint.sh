#!/usr/bin/env bash
# design-lint: hardcoded colours, off-scale spacing and font sizes, shadows on
# non-pressable elements. Reads the scales from docs/design/tokens.json.
# Prints counts per category and fails when any count exceeds its allowance
# or when zero source files were scanned. Installed by design-system as
# scripts/design-lint.sh and wired into the Makefile as `make design-lint`.
#
# Environment:
#   DESIGN_TOKENS        path to tokens.json (default docs/design/tokens.json)
#   DESIGN_LINT_ROOTS    space-separated source roots (default: src web/src app App Packages lib components)
#   DESIGN_LINT_EXCLUDE  extended regex of paths to skip (generated token files are always skipped)
#   ALLOW_COLOR ALLOW_SPACE ALLOW_FONT ALLOW_SHADOW ALLOW_RAW ALLOW_FAMILY
#                        allowed hits per category (default 0)
#   DESIGN_LINT_LIMIT    lines printed per category (default 40)
set -euo pipefail

TOKENS="${DESIGN_TOKENS:-docs/design/tokens.json}"
ROOTS="${DESIGN_LINT_ROOTS:-src web/src app App Packages lib components}"
GENERATED='(tokens\.css|theme\.ts|Theme\.kt|Color\.kt|Type\.kt|Shape\.kt|Theme\.swift|docs/design/|node_modules/|dist/|build/|\.expo/|coverage/|generated|__snapshots__|\.test\.|\.spec\.|\.stories\.|/e2e/|playwright)'
EXCLUDE="${DESIGN_LINT_EXCLUDE:-^$}"
ALLOW_COLOR="${ALLOW_COLOR:-0}"; ALLOW_SPACE="${ALLOW_SPACE:-0}"
ALLOW_FONT="${ALLOW_FONT:-0}"; ALLOW_SHADOW="${ALLOW_SHADOW:-0}"
ALLOW_RAW="${ALLOW_RAW:-0}"; ALLOW_FAMILY="${ALLOW_FAMILY:-0}"
LIMIT="${DESIGN_LINT_LIMIT:-40}"

# 1. Files to scan
files=()
for r in $ROOTS; do
  [ -d "$r" ] || continue
  while IFS= read -r f; do
    printf '%s' "$f" | grep -Eq "$GENERATED" && continue
    printf '%s' "$f" | grep -Eq "$EXCLUDE" && continue
    files+=("$f")
  done < <(find "$r" -type f \( -name '*.css' -o -name '*.scss' -o -name '*.tsx' -o -name '*.ts' \
      -o -name '*.jsx' -o -name '*.js' -o -name '*.kt' -o -name '*.kts' -o -name '*.swift' \
      -o -name '*.xml' -o -name '*.html' -o -name '*.vue' -o -name '*.svelte' \) | sort)
done
if [ "${#files[@]}" -eq 0 ]; then
  echo "design-lint: 0 files under [$ROOTS]; set DESIGN_LINT_ROOTS" >&2; exit 1
fi

# 2. Scales from tokens.json (defaults when absent)
SPACE="0 4 8 16 24 32 48 64 96"
SIZES="12 13 14 16 20 24 32 40 48"
if [ -f "$TOKENS" ] && command -v python3 >/dev/null; then
  SPACE=$(python3 -c 'import json,sys; t=json.load(open(sys.argv[1])); print(" ".join(str(v) for v in sorted(set(t["space"]["scale"].values()))))' "$TOKENS" 2>/dev/null || echo "$SPACE")
  SIZES=$(python3 -c 'import json,sys; t=json.load(open(sys.argv[1])); print(" ".join(str(int(v)) if float(v).is_integer() else str(v) for v in sorted(set(t["font"]["sizes"].values()))))' "$TOKENS" 2>/dev/null || echo "$SIZES")
  scale_source="$TOKENS"
else
  scale_source="defaults (no $TOKENS)"
fi
on_scale() { # $1 number, $2 scale
  local n="$1" v
  for v in $2; do [ "$v" = "$n" ] && return 0; done
  [ "$n" = "0" ] && return 0
  return 1
}
# For each line, take the fragments matching $2, pull the numbers matching $3
# from those fragments only, and report the first one that is not on scale $4.
# $1 is unused (keeps the call sites readable), stdin is file:line:text.
off_scale_hits() {
  local mre="$2" nre="$3" scale="$4" line m n hit
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    hit=""
    while IFS= read -r m; do
      for n in $(printf '%s' "$m" | grep -oE "$nre"); do
        on_scale "$n" "$scale" || { hit="$n"; break; }
      done
      [ -n "$hit" ] && break
    done < <(printf '%s' "${line#*:*:}" | grep -oE "$mre" || true)
    [ -n "$hit" ] && printf '%s  (%s not on scale)\n' "$line" "$hit"
  done
  return 0
}

# Always returns 0: under pipefail a false last test would fail the pipeline
# and set -e would end the lint with no output.
by_ext() { local e; for f in "${files[@]}"; do for e in "$@"; do [[ "$f" == *."$e" ]] && { printf '%s\0' "$f"; break; }; done; done; return 0; }
g() { # grep helper over a NUL list on stdin
  xargs -0 -r grep -nHE "$@" 2>/dev/null || true
}

# 3. Hardcoded colours
color_hits=$( {
  by_ext css scss tsx ts jsx js html vue svelte xml | g -e '#[0-9a-fA-F]{3}([0-9a-fA-F]{3}([0-9a-fA-F]{2})?)?\b' -e '\b(rgba?|hsla?|oklch|oklab|lab|lch)\(' \
    | grep -vE 'href="#|getElementById|url\(#|#!/|\$\{' || true
  by_ext kt kts | g -e 'Color\(0x' -e 'parseColor\('
  by_ext swift | g -e 'Color\((\.sRGB|red:|hex:)' -e 'UIColor\((red|white|hue):' -e 'Color\("#'
} | sort -u)

# 4. Off-scale spacing
space_hits=$( {
  by_ext css scss vue svelte html | g -e '\b(padding|margin|gap|row-gap|column-gap|inset|top|right|bottom|left)(-[a-z]+)?:\s*-?[0-9]+px' \
    | off_scale_hits _ '\b(padding|margin|gap|row-gap|column-gap|inset|top|right|bottom|left)(-[a-z]+)?:\s*-?[0-9]+px' '[0-9]+' "$SPACE"
  by_ext tsx jsx html vue svelte | g -e '\b(p|px|py|pt|pr|pb|pl|m|mx|my|mt|mr|mb|ml|gap|gap-x|gap-y|space-x|space-y|inset|top|right|bottom|left)-\[[0-9.]+(px|rem)\]' \
    | sed 's/$/  (arbitrary value)/'
  by_ext tsx ts jsx js | g -e '\b(padding|margin|gap|rowGap|columnGap)[A-Za-z]*:\s*-?[0-9]+\b' \
    | off_scale_hits _ '\b(padding|margin|gap|rowGap|columnGap)[A-Za-z]*:\s*-?[0-9]+\b' '[0-9]+' "$SPACE"
  by_ext kt kts | g -e '\b(padding|spacedBy|offset|Spacer|size|width|height)\([^)]*[0-9]+\.dp' \
    | off_scale_hits _ '\b(padding|spacedBy|offset|Spacer|size|width|height)\([^)]*[0-9]+\.dp' '[0-9]+' "$SPACE"
  by_ext swift | g -e '\.padding\([^)]*[0-9]+\)' -e '\bspacing:\s*[0-9]+' -e 'minLength:\s*[0-9]+' \
    | off_scale_hits _ '\.padding\([^)]*[0-9]+\)|\bspacing:\s*[0-9]+|minLength:\s*[0-9]+' '[0-9]+' "$SPACE"
} | sort -u)

# 5. Off-scale font sizes
font_hits=$( {
  by_ext css scss vue svelte html | g -e 'font-size:\s*[0-9.]+px' | off_scale_hits _ 'font-size:\s*[0-9.]+px' '[0-9.]+' "$SIZES"
  by_ext css scss vue svelte html | g -e 'font-size:\s*[0-9.]+rem' | sed 's/$/  (rem literal; use a size token)/'
  by_ext tsx jsx html vue svelte | g -e '\btext-\[[0-9.]+(px|rem)\]' | sed 's/$/  (arbitrary value)/'
  by_ext tsx ts jsx js | g -e '\bfontSize:\s*[0-9.]+\b' | off_scale_hits _ '\bfontSize:\s*[0-9.]+' '[0-9.]+' "$SIZES"
  by_ext kt kts | g -e 'fontSize\s*=\s*[0-9.]+\.sp' | off_scale_hits _ 'fontSize\s*=\s*[0-9.]+\.sp' '[0-9]+(\.[0-9]+)?' "$SIZES"
  by_ext swift | g -e '\.system\(size:\s*[0-9.]+' -e '\.custom\("[^"]+",\s*size:\s*[0-9.]+' | off_scale_hits _ 'size:\s*[0-9.]+' '[0-9.]+' "$SIZES"
} | sort -u)

# 6. Shadows on non-pressable elements (elevation means pressable or overlay)
PRESSABLE='button|<a |\[role=.?(button|link|dialog|menu|tooltip)|pressable|clickable|onClick|onTap|href=|Button|Dialog|Sheet|Popover|Popup|Menu|Dropdown|Toast|Snackbar|Tooltip|Overlay|Modal|Card\(onClick|:hover|:focus|:active|elevation-[123]|shadow-[123]\b'
shadow_hits=$( {
  for f in "${files[@]}"; do
    # (pattern) with the leading paren: bash 3.2, the macOS shell, ends a
    # $( ) at the bare ) of a case pattern and fails with a syntax error.
    case "$f" in (*.css|*.scss) awk -v f="$f" -v allow="$PRESSABLE" '
      index($0, "{") > 0 { sel=$0; sub(/\{.*$/, "", sel); gsub(/^[[:space:]]+|[[:space:]]+$/, "", sel) }
      /box-shadow[[:space:]]*:/ && $0 !~ /box-shadow[[:space:]]*:[[:space:]]*none/ { if (sel !~ allow) printf "%s:%d:%s  (selector: %s)\n", f, NR, $0, sel }
    ' "$f";; esac
  done
  by_ext tsx jsx html vue svelte | g -e '\bshadow-(sm|md|lg|xl|2xl|inner|[0-9])\b' -e '\bdrop-shadow' | grep -vE "$PRESSABLE" || true
  by_ext kt kts | g -e '\.shadow\(' -e 'shadowElevation\s*=' | grep -vE "$PRESSABLE" || true
  by_ext swift | g -e '\.shadow\(' | grep -vE "$PRESSABLE" || true
} | sort -u)

# 7. Raw elements where the component library has the component. Screens are
#    assembled from src/components/ui (shadcn on the default stack); a raw
#    <table> or <button> in feature code is a page styled by hand, and pages
#    styled by hand drift apart. The library folder itself is exempt.
raw_hits=$( {
  by_ext tsx jsx | g -e '<(table|button|input|select|textarea|dialog)[[:space:]>/]' | grep -vE '(^|/)components/ui/' || true
} | sort -u)

# 8. One-off font families: faces come from the tokens (font-sans, font-mono),
#    never from a page.
family_hits=$( {
  by_ext css scss vue svelte html | g -e 'font-family:' | grep -vE 'var\(--font' || true
  by_ext tsx ts jsx js | g -e '\bfontFamily:' -e '\bfont-\[[^]]+\]' || true
} | sort -u)

count() { [ -n "$1" ] && printf '%s\n' "$1" | wc -l | tr -d ' ' || echo 0; }
c=$(count "$color_hits"); s=$(count "$space_hits"); fz=$(count "$font_hits"); d=$(count "$shadow_hits")
r=$(count "$raw_hits"); ff=$(count "$family_hits")

show() { # $1 title, $2 hits, $3 count, $4 allowance
  [ "$3" -gt 0 ] || return 0
  printf '\n## %s: %s hits (allowance %s)\n' "$1" "$3" "$4"
  printf '%s\n' "$2" | head -n "$LIMIT"
  [ "$3" -gt "$LIMIT" ] && printf '... %s more\n' "$(( $3 - LIMIT ))"
  return 0
}
show "hardcoded colours" "$color_hits" "$c" "$ALLOW_COLOR"
show "off-scale spacing" "$space_hits" "$s" "$ALLOW_SPACE"
show "off-scale font sizes" "$font_hits" "$fz" "$ALLOW_FONT"
show "shadows on non-pressable elements" "$shadow_hits" "$d" "$ALLOW_SHADOW"
show "raw elements where src/components/ui has the component" "$raw_hits" "$r" "$ALLOW_RAW"
show "one-off font families" "$family_hits" "$ff" "$ALLOW_FAMILY"

echo
echo "design-lint: ${#files[@]} files, scales from $scale_source (space: $SPACE; sizes: $SIZES)"
echo "design-lint: $c colours, $s spacing, $fz font sizes, $d shadows, $r raw elements, $ff font families (allowance $ALLOW_COLOR/$ALLOW_SPACE/$ALLOW_FONT/$ALLOW_SHADOW/$ALLOW_RAW/$ALLOW_FAMILY)"
fail=0
[ "$c" -le "$ALLOW_COLOR" ] || fail=1
[ "$s" -le "$ALLOW_SPACE" ] || fail=1
[ "$fz" -le "$ALLOW_FONT" ] || fail=1
[ "$d" -le "$ALLOW_SHADOW" ] || fail=1
[ "$r" -le "$ALLOW_RAW" ] || fail=1
[ "$ff" -le "$ALLOW_FAMILY" ] || fail=1
[ "$fail" -eq 0 ] || { echo "design-lint: failed"; exit 1; }
echo "design-lint: passed"
