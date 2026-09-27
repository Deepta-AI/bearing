#!/bin/sh
# design-lint: hardcoded colours, off-scale spacing and font sizes, shadows on
# non-pressable elements, raw elements where the component library has one,
# one-off font families. Installed by design-system as scripts/design-lint.sh
# and wired into the Makefile as `make design-lint`.
#
# POSIX sh and awk only, so it runs in node:*-alpine, busybox and macOS CI
# images that have no bash and no python3. Comments are stripped before
# matching, so a hex in a comment or an issue reference (#123) is not a colour.
#
# Existing debt lives in a baseline keyed by category, file and literal with a
# count per key, never in a total: a new literal anywhere, including a second
# copy on a line that already has one, fails; paying one debt does not make
# room for another. A baselined literal that is gone also fails until the
# baseline is rewritten, so the file only ever shrinks.
#
#   sh scripts/design-lint.sh                    check (the gate)
#   sh scripts/design-lint.sh --write-baseline   record today's findings; on an
#                                                existing baseline it only lowers
#                                                counts and refuses to add keys
#
# Environment:
#   DESIGN_LINT_ROOTS     source roots (default: src web/src app App Packages lib components)
#   DESIGN_LINT_EXCLUDE   extended regex of paths to skip (token and generated files always are)
#   DESIGN_LINT_BASELINE  baseline file (default scripts/design-lint.baseline)
#   DESIGN_SPACE_SCALE    spacing scale in px, e.g. "4 8 12 16 24 32 48"
#   DESIGN_FONT_SCALE     font-size scale in px, e.g. "13 15 20 28"
#   DESIGN_TOKENS         tokens.json to read the scales from (default docs/design/tokens.json)
#   DESIGN_TOKENS_CSS     CSS file whose --space-* and --font-size-*/--text-* values are the scales
#   DESIGN_LINT_LIMIT     findings printed per category (default 40)
#   DESIGN_LINT_LIBRARY   regex of the component library folder, exempt from the raw-element
#                         rule (default (^|/)components/ui/)
#   DESIGN_LINT_RULES     the rules that gate, any of: colour spacing font-size shadow raw family
#                         (default all six). Set it to what the team asked for; a rule nobody
#                         agreed to fails their next merge request for a reason they never saw.
# Vendored and third-party code (vendor/, third_party/, *.min.css) is never
# scanned: it is not the team's debt, and upgrading it would fail the gate.
# Scale source order: the two env scales, tokens.json (read with node or
# python3 when either exists), the token CSS file, built-in defaults. The
# source used is printed; check it is the one the team means.
set -eu

ROOTS="${DESIGN_LINT_ROOTS:-src web/src app App Packages lib components}"
EXCLUDE="${DESIGN_LINT_EXCLUDE:-^$}"
BASELINE="${DESIGN_LINT_BASELINE:-scripts/design-lint.baseline}"
TOKENS="${DESIGN_TOKENS:-docs/design/tokens.json}"
LIMIT="${DESIGN_LINT_LIMIT:-40}"
LIBRARY="${DESIGN_LINT_LIBRARY:-(^|/)components/ui/}"
RULES="${DESIGN_LINT_RULES:-colour spacing font-size shadow raw family}"
GENERATED='(^|/)(tokens\.css|tokens\.json|theme\.ts|Theme\.kt|Color\.kt|Type\.kt|Shape\.kt|Theme\.swift)$|/values[^/]*/(colors|themes|dimens)\.xml$|docs/design/|node_modules/|dist/|build/|\.expo/|coverage/|generated|__snapshots__|\.test\.|\.spec\.|\.stories\.|/e2e/|playwright|(^|/)(vendor|vendored|third[_-]party)/|\.min\.(css|js)$'
MODE="check"
case "${1:-}" in
  --write-baseline) MODE="write" ;;
  "") ;;
  *) echo "usage: sh scripts/design-lint.sh [--write-baseline]" >&2; exit 2 ;;
esac

TMP=$(mktemp -d "${TMPDIR:-/tmp}/design-lint.XXXXXX")
trap 'rm -rf "$TMP"' EXIT INT TERM

# 1. Files to scan
for r in $ROOTS; do
  [ -d "$r" ] || continue
  find "$r" -type f \( -name '*.css' -o -name '*.scss' -o -name '*.less' -o -name '*.tsx' \
    -o -name '*.ts' -o -name '*.jsx' -o -name '*.js' -o -name '*.mjs' -o -name '*.kt' \
    -o -name '*.kts' -o -name '*.swift' -o -name '*.xml' -o -name '*.html' -o -name '*.vue' \
    -o -name '*.svelte' \)
done | grep -Ev "$GENERATED" | grep -Ev "$EXCLUDE" | sort -u > "$TMP/files" || true
NFILES=$(wc -l < "$TMP/files" | tr -d ' ')
if [ "$NFILES" -eq 0 ]; then
  echo "design-lint: 0 files under [$ROOTS]; set DESIGN_LINT_ROOTS" >&2
  exit 1
fi

# 2. Scales
SPACE="${DESIGN_SPACE_SCALE:-}"; SIZES="${DESIGN_FONT_SCALE:-}"; SRC="env"
if [ -z "$SPACE" ] || [ -z "$SIZES" ]; then
  if [ -f "$TOKENS" ]; then
    js='const t=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));const u=o=>[...new Set(Object.values(o||{}).filter(v=>typeof v==="number"))].sort((a,b)=>a-b).join(" ");console.log(u((t.space||{}).scale)+"|"+u((t.font||{}).sizes))'
    py='import json,sys;t=json.load(open(sys.argv[1]));u=lambda o:" ".join("%g"%v for v in sorted(set(x for x in (o or {}).values() if isinstance(x,(int,float)))));print(u(t.get("space",{}).get("scale"))+"|"+u(t.get("font",{}).get("sizes")))'
    got=""
    if command -v node >/dev/null 2>&1; then got=$(node -e "$js" "$TOKENS" 2>/dev/null || true)
    elif command -v python3 >/dev/null 2>&1; then got=$(python3 -c "$py" "$TOKENS" 2>/dev/null || true); fi
    if [ -n "$got" ] && [ "$got" != "|" ]; then
      [ -n "$SPACE" ] || SPACE="${got%%|*}"; [ -n "$SIZES" ] || SIZES="${got#*|}"; SRC="$TOKENS"
    fi
  fi
fi
if [ -z "$SPACE" ] || [ -z "$SIZES" ]; then
  CSS="${DESIGN_TOKENS_CSS:-}"
  if [ -z "$CSS" ]; then
    for c in src/styles/tokens.css web/src/styles/tokens.css app/styles/tokens.css docs/design/tokens.css; do
      if [ -f "$c" ]; then CSS="$c"; break; fi
    done
  fi
  if [ -n "$CSS" ] && [ -f "$CSS" ]; then
    got=$(awk '
      function px(v) { if (v ~ /rem$/) { sub(/rem$/, "", v); return v * 16 } sub(/px$/, "", v); return v + 0 }
      function joined(a,   k, out, n, i, j, t, v) {
        n = 0; for (k in a) v[++n] = k + 0
        for (i = 2; i <= n; i++) { t = v[i]; for (j = i - 1; j >= 1 && v[j] > t; j--) v[j + 1] = v[j]; v[j + 1] = t }
        out = ""; for (i = 1; i <= n; i++) out = out (i > 1 ? " " : "") v[i]
        return out
      }
      {
        line = $0
        while (match(line, /--[A-Za-z0-9-]+[ \t]*:[ \t]*[0-9.]+(px|rem)/)) {
          d = substr(line, RSTART, RLENGTH); line = substr(line, RSTART + RLENGTH)
          k = index(d, ":"); name = substr(d, 3, k - 3); v = substr(d, k + 1); gsub(/[ \t]/, "", v)
          if (name ~ /line-height|leading/) continue
          if (name ~ /^(space|spacing|gap)(-|$)/) sp[px(v)] = 1
          else if (name ~ /^(font-size|text|fs)(-|$)/) fs[px(v)] = 1
        }
      }
      END { printf "%s|%s\n", joined(sp), joined(fs) }' "$CSS")
    s1="${got%%|*}"; s2="${got#*|}"
    if [ -n "$s1" ] || [ -n "$s2" ]; then
      [ -n "$SPACE" ] || SPACE="$s1"; [ -n "$SIZES" ] || SIZES="$s2"; SRC="$CSS"
    fi
  fi
fi
if [ -z "$SPACE" ]; then SPACE="4 8 16 24 32 48 64 96"; SRC="$SRC (space: defaults)"; fi
if [ -z "$SIZES" ]; then SIZES="12 13 14 16 20 24 32 40 48"; SRC="$SRC (sizes: defaults)"; fi

# 3. Findings, one line per occurrence: category TAB file TAB line TAB literal TAB note
cat > "$TMP/lint.awk" <<'AWK'
function emit(cat, lit, note,   c) {
  c = cat; gsub(/ /, "-", c)
  if (index(" " RULES " ", " " c " ") == 0) return
  gsub(/[ \t]+/, " ", lit); gsub(/^ | $/, "", lit)
  printf "%s\t%s\t%d\t%s\t%s\n", cat, FILE, LNO, lit, note
}
function onscale(n, scale) {
  n = n + 0; if (n < 0) n = -n
  if (n == 0) return 1
  return index(" " scale " ", " " n " ") > 0
}
# Comments out, strings kept. inblock and inhtml carry across lines.
function strip(s,   out, i, n, c, c2, q) {
  out = ""; n = length(s); q = ""
  for (i = 1; i <= n; i++) {
    c = substr(s, i, 1); c2 = substr(s, i, 2)
    if (inblock) { if (c2 == "*/") { inblock = 0; i++ }; continue }
    if (inhtml) { if (substr(s, i, 3) == "-->") { inhtml = 0; i += 2 }; continue }
    if (q != "") {
      out = out c
      if (c == "\\") { out = out substr(s, i + 1, 1); i++ } else if (c == q) q = ""
      continue
    }
    if (c2 == "/*") { inblock = 1; i++; continue }
    if (markup && substr(s, i, 4) == "<!--") { inhtml = 1; i += 3; continue }
    if (linecomments && c2 == "//" && (i == 1 || substr(s, i - 1, 1) !~ /[:\\]/)) break
    if (c == "\"" || c == "\047" || c == "`") q = c
    out = out c
  }
  return out
}
# A # that is a link fragment or an element id, not a colour.
function anchor(pre) {
  return pre ~ /(^|[^A-Za-z0-9_])(href|to|hash|anchor|id|target|fragment)[ \t]*(===|==|=|:)?[ \t]*[{]?[ \t]*["\047`]$/ \
    || pre ~ /(url|getElementById|querySelector|querySelectorAll|closest)\([ \t]*["\047`]?$/
}
function hexes(s,   rest, off, i, j, run, pre, p, nx, post, ok, n) {
  rest = s; off = 0
  while ((i = index(rest, "#")) > 0) {
    j = i + 1; run = ""
    while (substr(rest, j, 1) ~ /[0-9A-Fa-f]/) { run = run substr(rest, j, 1); j++ }
    pre = substr(s, 1, off + i - 1); p = substr(pre, length(pre), 1)
    n = length(run); nx = substr(rest, j, 1); post = substr(rest, j)
    ok = (n == 3 || n == 4 || n == 6 || n == 8) && nx !~ /[A-Za-z0-9_-]/ && p !~ /[A-Za-z0-9_&$\\]/
    if (ok && anchor(pre)) ok = 0
    if (ok && run ~ /^[0-9]+$/ && pre !~ /[:=(,][ \t]*["\047`]?$/) ok = 0
    if (ok && kind == "css" && post ~ /^[^;{}]*[{]/) ok = 0
    if (ok) emit("colour", "#" run, "")
    off += j - 1; rest = substr(rest, j)
  }
}
function colourfns(s,   ls, rest, off, name, p, args, k) {
  ls = tolower(s); rest = ls; off = 0
  while (match(rest, /(rgba?|hsla?|hwb|oklch|oklab|lab|lch|color-mix|color)\(/)) {
    name = substr(rest, RSTART, RLENGTH - 1)
    p = (off + RSTART > 1) ? substr(ls, off + RSTART - 1, 1) : ""
    args = substr(s, off + RSTART + RLENGTH)
    k = index(args, ")"); if (k > 0) args = substr(args, 1, k - 1)
    off += RSTART + RLENGTH - 1; rest = substr(ls, off + 1)
    if (p ~ /[a-z0-9_$.-]/) continue
    if (name == "color" && kind == "js") continue
    if (args ~ /^[ \t]*var\(/) continue
    emit("colour", name "(" args ")", "")
  }
}
function named(val, prop,   v, w) {
  v = " " tolower(val) " "; gsub(/[^a-z-]/, " ", v)
  if (match(v, / (white|black|red|green|blue|gray|grey|silver|orange|yellow|purple|pink|navy|teal|maroon|olive|lime|aqua|fuchsia|brown|gold|indigo|violet|crimson|tomato|coral) /)) {
    w = substr(v, RSTART + 1, RLENGTH - 2); emit("colour", w, prop)
  }
}
# Every px or rem length in a value, rem at 16 px, checked against a scale.
function lengths(val, cat, scale, prop,   v, t, n, p) {
  v = val; gsub(/var\([^)]*\)/, " ", v)
  while (match(v, /-?[0-9]*\.?[0-9]+(px|rem)/)) {
    t = substr(v, RSTART, RLENGTH)
    p = (RSTART > 1) ? substr(v, RSTART - 1, 1) : ""
    v = substr(v, RSTART + RLENGTH)
    if (p ~ /[A-Za-z0-9_.-]/) continue
    n = t; if (n ~ /rem$/) { sub(/rem$/, "", n); n = n * 16 } else sub(/px$/, "", n)
    if (!onscale(n, scale)) emit(cat, t, prop " off scale")
  }
}
function pressable(txt) { return txt ~ PRESS }
function cssdecls(s,   rest, d, k, prop, val) {
  if (index(s, "{") > 0) { sel = s; sub(/[{].*$/, "", sel); sub(/^.*[}]/, "", sel); gsub(/^[ \t]+|[ \t]+$/, "", sel) }
  rest = s
  while (match(rest, /[A-Za-z-]+[ \t]*:[^;{}]*/)) {
    d = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
    k = index(d, ":"); prop = tolower(substr(d, 1, k - 1)); gsub(/[ \t]/, "", prop); val = substr(d, k + 1)
    if (prop ~ /^(padding|margin)(-(top|right|bottom|left|inline|block|inline-start|inline-end|block-start|block-end))?$/ \
        || prop ~ /^(gap|row-gap|column-gap|inset|inset-inline|inset-block|top|right|bottom|left)$/) lengths(val, "spacing", SPACE, prop)
    else if (prop == "font-size" || prop == "font") lengths(val, "font size", SIZES, prop)
    else if (prop == "font-family") { if (val !~ /var\(--/ && val !~ /^[ \t]*(inherit|initial|unset)[ \t]*$/) emit("family", val, "") }
    else if (prop == "box-shadow") { if (val !~ /^[ \t]*none/ && !pressable(sel)) emit("shadow", val, "selector " sel) }
    if (prop ~ /^(color|background|background-color|border|border-(top|right|bottom|left|color)|outline|outline-color|fill|stroke|box-shadow|text-decoration-color|caret-color|accent-color)$/) named(val, prop)
  }
}
# Style objects: numbers are px, strings are parsed for px and rem.
function jspairs(s,   rest, d, k, key, val, isnum) {
  rest = s
  while (match(rest, /[A-Za-z_$][A-Za-z0-9_$]*["\047]?[ \t]*:[ \t]*(-?[0-9]*\.?[0-9]+|"[^"]*"|\047[^\047]*\047|`[^`]*`)/)) {
    d = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
    k = index(d, ":"); key = substr(d, 1, k - 1); gsub(/["\047 \t]/, "", key)
    val = substr(d, k + 1); gsub(/^[ \t]+/, "", val)
    isnum = (val ~ /^-?[0-9.]+$/)
    if (key ~ /^(padding|margin)(Top|Right|Bottom|Left|Inline|Block|InlineStart|InlineEnd|BlockStart|BlockEnd|Horizontal|Vertical)?$/ \
        || key ~ /^(gap|rowGap|columnGap|inset|top|right|bottom|left)$/) {
      if (isnum) { if (!onscale(val, SPACE)) emit("spacing", key ": " val, "off scale") }
      else lengths(val, "spacing", SPACE, key)
    } else if (key == "fontSize") {
      if (isnum) { if (!onscale(val, SIZES)) emit("font size", key ": " val, "off scale") }
      else lengths(val, "font size", SIZES, key)
    } else if (key == "fontFamily") {
      if (val !~ /var\(--/) emit("family", key ": " val, "")
    } else if (key == "boxShadow") {
      if (val !~ /none/ && !pressable(LINE)) emit("shadow", key ": " val, "")
    } else if (key ~ /^(color|background|backgroundColor|borderColor|border|borderTop|borderBottom|outline|outlineColor|fill|stroke|tintColor|shadowColor)$/ && !isnum) {
      named(val, key)
    }
  }
}
function tailwind(s,   rest, t) {
  rest = s
  while (match(rest, /(^|[^A-Za-z0-9_])-?(p|px|py|pt|pr|pb|pl|ps|pe|m|mx|my|mt|mr|mb|ml|ms|me|gap|gap-x|gap-y|space-x|space-y|inset|inset-x|inset-y|top|right|bottom|left)-\[[^]]*\]/)) {
    t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); sub(/^[^A-Za-z-]/, "", t)
    emit("spacing", t, "arbitrary value")
  }
  rest = s
  while (match(rest, /(^|[^A-Za-z0-9_])text-\[[0-9.]+(px|rem)\]/)) {
    t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); sub(/^[^a-z]/, "", t)
    emit("font size", t, "arbitrary value")
  }
  rest = s
  while (match(rest, /(^|[^A-Za-z0-9_-])(shadow-(sm|md|lg|xl|2xl|inner)|shadow|drop-shadow(-[a-z0-9]+)?)([^A-Za-z0-9_-]|$)/)) {
    t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH)
    gsub(/^[^a-z]|[^a-z0-9-]$/, "", t)
    if (t == "shadow" && s !~ /className|class=|cn\(|cva\(/) continue
    if (!pressable(LINE)) emit("shadow", t, "")
  }
  rest = s
  while (match(rest, /(^|[^A-Za-z0-9_-])font-\[[^]]*\]/)) {
    t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); sub(/^[^a-z]/, "", t)
    emit("family", t, "")
  }
}
# Screens are assembled from components/ui; a raw element in feature code is a
# page styled by hand. The library folder itself is exempt.
function raw(s,   rest, t) {
  if (FILE ~ LIBRARY) return
  rest = s
  while (match(rest, /<(table|button|input|select|textarea|dialog)([ \t>\/]|$)/)) {
    t = substr(rest, RSTART + 1, RLENGTH - 1); rest = substr(rest, RSTART + RLENGTH); gsub(/[^a-z]/, "", t)
    emit("raw", "<" t ">", "")
  }
}
function native(s,   rest, t) {
  if (kind == "kt") {
    rest = s
    while (match(rest, /Color\(0x[0-9A-Fa-f]+\)|parseColor\([^)]*\)/)) { emit("colour", substr(rest, RSTART, RLENGTH), ""); rest = substr(rest, RSTART + RLENGTH) }
    if (s ~ /(padding|spacedBy|offset|Spacer)\(/) {
      rest = s
      while (match(rest, /[0-9.]+\.dp/)) { t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); sub(/\.dp$/, "", t); if (!onscale(t, SPACE)) emit("spacing", t ".dp", "off scale") }
    }
    rest = s
    while (match(rest, /fontSize[ \t]*=[ \t]*[0-9.]+\.sp/)) { t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); sub(/^.*=[ \t]*/, "", t); sub(/\.sp$/, "", t); if (!onscale(t, SIZES)) emit("font size", t ".sp", "off scale") }
    if (s ~ /\.shadow\(|shadowElevation[ \t]*=/ && !pressable(s)) emit("shadow", "shadow", "")
  } else if (kind == "swift") {
    rest = s
    while (match(rest, /Color\((\.sRGB|red:|hex:)[^)]*\)|UIColor\((red|white|hue):[^)]*\)|Color\("#[^"]*"\)/)) { emit("colour", substr(rest, RSTART, RLENGTH), ""); rest = substr(rest, RSTART + RLENGTH) }
    rest = s
    while (match(rest, /\.padding\([^)]*[0-9]+\)|spacing:[ \t]*[0-9.]+/)) { t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); sub(/^[^0-9]*/, "", t); sub(/[^0-9.].*$/, "", t); if (!onscale(t, SPACE)) emit("spacing", t, "off scale") }
    rest = s
    while (match(rest, /size:[ \t]*[0-9.]+/)) { t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); sub(/^size:[ \t]*/, "", t); if (!onscale(t, SIZES)) emit("font size", t, "off scale") }
    if (s ~ /\.shadow\(/ && !pressable(s)) emit("shadow", "shadow", "")
  } else if (kind == "xml") {
    rest = s
    while (match(rest, /(padding|margin)[A-Za-z]*="[0-9.]+dp"/)) { t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); sub(/^[^"]*"/, "", t); sub(/dp"$/, "", t); if (!onscale(t, SPACE)) emit("spacing", t "dp", "off scale") }
    rest = s
    while (match(rest, /textSize="[0-9.]+sp"/)) { t = substr(rest, RSTART, RLENGTH); rest = substr(rest, RSTART + RLENGTH); sub(/^[^"]*"/, "", t); sub(/sp"$/, "", t); if (!onscale(t, SIZES)) emit("font size", t "sp", "off scale") }
  }
}
BEGIN {
  PRESS = "button|<a[ \t>]|role=.?(button|link|dialog|menu|tooltip)|pressable|clickable|onClick|onPress|onTap|href=|Button|Dialog|Sheet|Popover|Popup|Menu|Dropdown|Toast|Snackbar|Tooltip|Overlay|Modal|Card\\(onClick|:hover|:focus|:active|elevation-[123]|shadow-[123]"
  while ((getline FILE < LIST) > 0) {
    ext = tolower(FILE); sub(/^.*\./, "", ext)
    kind = "js"; markup = 0; linecomments = 1
    if (ext == "css") { kind = "css"; linecomments = 0 }
    else if (ext == "scss" || ext == "less") kind = "css"
    else if (ext == "html" || ext == "vue" || ext == "svelte") { kind = "markup"; markup = 1 }
    else if (ext == "xml") { kind = "xml"; markup = 1; linecomments = 0 }
    else if (ext == "kt" || ext == "kts") kind = "kt"
    else if (ext == "swift") kind = "swift"
    inblock = 0; inhtml = 0; sel = ""; LNO = 0
    while ((getline LINE < FILE) > 0) {
      LNO++
      s = strip(LINE)
      if (s ~ /^[ \t]*$/) continue
      if (kind == "css" || kind == "markup" || kind == "js" || kind == "xml") { hexes(s); colourfns(s) }
      if (kind == "css" || kind == "markup") cssdecls(s)
      if (kind == "js" || kind == "markup") { jspairs(s); tailwind(s) }
      if (ext == "tsx" || ext == "jsx") raw(s)
      if (kind == "kt" || kind == "swift" || kind == "xml") native(s)
    }
    close(FILE)
  }
}
AWK
awk -v LIST="$TMP/files" -v LIBRARY="$LIBRARY" -v RULES="$RULES" -v SPACE="$SPACE" -v SIZES="$SIZES" -f "$TMP/lint.awk" > "$TMP/findings"
NFIND=$(wc -l < "$TMP/findings" | tr -d ' ')

# 4. Compare with the baseline, or write it.
: > "$TMP/base"
HAVE_BASE=0
if [ -f "$BASELINE" ]; then HAVE_BASE=1; grep -v '^#' "$BASELINE" > "$TMP/base" || true; fi

if [ "$MODE" = write ]; then
  grow=0
  awk -F '\t' -v have="$HAVE_BASE" -v out="$TMP/newbase" '
    FILENAME == ARGV[1] { if (NF >= 4) base[$1 FS $2 FS $3] = $4; next }
    { cur[$1 FS $2 FS $4]++ }
    END {
      grow = 0; printf "" > out
      for (k in cur) {
        n = cur[k]
        if (have && !(k in base)) { split(k, p, FS); printf "design-lint: not added (new): %s %s %s\n", p[1], p[2], p[3]; grow++; continue }
        if (have && n > base[k] + 0) { split(k, p, FS); printf "design-lint: not raised (%d > %d): %s %s %s\n", n, base[k], p[1], p[2], p[3]; grow++; n = base[k] }
        printf "%s\t%d\n", k, n > out
      }
      close(out)
      exit (grow > 0 ? 1 : 0)
    }' "$TMP/base" "$TMP/findings" || grow=1
  mkdir -p "$(dirname "$BASELINE")"
  { echo "# design-lint baseline: category<TAB>file<TAB>literal<TAB>count. Only ever shrinks."
    sort "$TMP/newbase"; } > "$BASELINE"
  n=$(grep -vc '^#' "$BASELINE" || true)
  echo "design-lint: $NFILES files, $NFIND findings; wrote $BASELINE with $n keys"
  if [ "$grow" -ne 0 ]; then echo "design-lint: the baseline may only shrink; fix the new literals above"; exit 1; fi
  exit 0
fi

awk -F '\t' -v limit="$LIMIT" '
  FILENAME == ARGV[1] { if (NF >= 4) base[$1 FS $2 FS $3] = $4; next }
  {
    k = $1 FS $2 FS $4; seen[k]++
    isnew = (seen[k] > base[k] + 0)
    total[$1]++; if (isnew) fresh[$1]++
    shown[$1]++
    if (shown[$1] <= limit) printf "%s %s %s:%s: %s%s\n", (isnew ? "NEW" : "old"), $1, $2, $3, $4, ($5 != "" ? "  (" $5 ")" : "") > "/dev/stderr"
  }
  END {
    stale = 0
    for (k in base) if (seen[k] + 0 < base[k] + 0) {
      split(k, p, FS); printf "gone %s %s: %s (baseline %d, now %d)\n", p[1], p[2], p[3], base[k], seen[k] + 0 > "/dev/stderr"
      stale += base[k] - seen[k]
    }
    printf "%d %d %d %d %d %d|", total["colour"], total["spacing"], total["font size"], total["shadow"], total["raw"], total["family"]
    printf "%d|%d\n", fresh["colour"] + fresh["spacing"] + fresh["font size"] + fresh["shadow"] + fresh["raw"] + fresh["family"], stale
  }' "$TMP/base" "$TMP/findings" 2> "$TMP/report" > "$TMP/sum"

sed 's/^/  /' "$TMP/report"
IFS='|' read -r totals nnew stale < "$TMP/sum"
# shellcheck disable=SC2086 # split the six counts on purpose
set -- $totals
echo
echo "design-lint: $NFILES files, scales from $SRC (space: $SPACE; sizes: $SIZES); rules: $RULES"
echo "design-lint: $1 colours, $2 spacing, $3 font sizes, $4 shadows, $5 raw elements, $6 font families; $nnew new, $stale fixed but still baselined ($BASELINE)"
if [ "$nnew" -gt 0 ]; then echo "design-lint: failed"; exit 1; fi
if [ "$stale" -gt 0 ]; then echo "design-lint: failed (lower the baseline: sh scripts/design-lint.sh --write-baseline)"; exit 1; fi
echo "design-lint: passed"
