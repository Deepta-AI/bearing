#!/usr/bin/env bash
# tests/unit/design_sync.sh: the --hash and --sync modes of
# plugins/bearing/skills/design-system/templates/design-lint.sh. design-system
# derives docs/design/tokens.json from root DESIGN.md frontmatter tokens, else
# from the picked direction in approved.json, and records the source's path and
# sha256 in meta. --hash prints sha256:<64 hex> of a file's bytes; --sync
# re-hashes the recorded source and fails with both hashes and the path when it
# changed, fails when an approved-direction source has been overtaken by a
# DESIGN.md that now carries tokens, and fails on zero input with a count line.
# It runs with sh, awk and sed alone (no bash, python3 or node).
set -u
. "$(dirname "$0")/../lib/assert.sh"
LINT="$KIT/plugins/bearing/skills/design-system/templates/design-lint.sh"

hex_of() { # the reference hash, by whichever tool this machine has
  if command -v sha256sum >/dev/null 2>&1; then sha256sum < "$1" | awk '{print $1}'
  else shasum -a 256 < "$1" | awk '{print $1}'; fi
}
tokens() { # tokens <dir> <source> <path> <hash>: a tokens.json with that meta
  mkdir -p "$1/docs/design"
  cat > "$1/docs/design/tokens.json" <<JSON
{
  "meta": {
    "name": "Invite",
    "version": 1,
    "source": "$2",
    "sourcePath": "$3",
    "sourceHash": "$4"
  },
  "space": { "scale": { "1": 4, "2": 8 } }
}
JSON
}
repo() { # a repo whose tokens were derived from its root DESIGN.md
  local d; d="$(tmpdir)"
  cat > "$d/DESIGN.md" <<'MD'
---
name: Invite
description: Invite a teammate
colors:
  primary: "#1f4e79"
rounded:
  sm: 6px
---
# Design System: Invite
MD
  tokens "$d" design-md DESIGN.md "sha256:$(hex_of "$d/DESIGN.md")"
  printf '%s' "$d"
}
seeded() { # a repo whose tokens came from the picked direction (seed DESIGN.md)
  local d a; d="$(tmpdir)"
  printf -- '---\nname: Invite\ndescription: Invite a teammate\n---\n# Invite\n' > "$d/DESIGN.md"
  a="docs/design/variants/invite/approved.json"
  mkdir -p "$d/docs/design/variants/invite"
  printf '{"round": 1, "source": "impeccable", "chosen": "harbour", "direction": {"palette": {"accent": "#1f4e79"}}}\n' > "$d/$a"
  tokens "$d" approved-direction "$a" "sha256:$(hex_of "$d/$a")"
  printf '%s' "$d"
}
run() { (cd "$1" && shift && env "$@"); }

t_begin "--hash prints the source's sha256"
d="$(repo)"
assert_exit 0 run "$d" sh "$LINT" --hash DESIGN.md
assert_eq "sha256:$(hex_of "$d/DESIGN.md")" "$T_OUT" "hash line"
case "$T_OUT" in sha256:????????????????????????????????????????????????????????????????) ok=1 ;; *) ok=0 ;; esac
assert_eq 1 "$ok" "sha256:<64 hex> shape"
assert_exit 1 run "$d" sh "$LINT" --hash missing.md
assert_contains "$T_OUT" "design-sync: 0 sources checked (missing.md missing)"
assert_exit 2 run "$d" sh "$LINT" --hash
t_end

t_begin "tokens derived from this DESIGN.md pass with the count"
d="$(repo)"
h="$(hex_of "$d/DESIGN.md")"
assert_exit 0 run "$d" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: 1 source checked, DESIGN.md matches tokens.json (sha256:$(printf '%s' "$h" | cut -c1-12))"
t_end

t_begin "DESIGN.md changed after the tokens fails with both hashes"
d="$(repo)"
old="$(hex_of "$d/DESIGN.md")"
printf 'one more line\n' >> "$d/DESIGN.md"
new="$(hex_of "$d/DESIGN.md")"
assert_exit 1 run "$d" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: DESIGN.md is sha256:$new, tokens.json was derived from sha256:$old"
assert_contains "$T_OUT" "rerun design-system to re-derive the tokens"
assert_contains "$T_OUT" "design-sync: 1 source checked"
t_end

t_begin "no DESIGN.md, no tokens.json or no sourceHash fails on zero input"
d="$(repo)"; rm "$d/DESIGN.md"
assert_exit 1 run "$d" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: 0 sources checked (DESIGN.md missing)"
d="$(repo)"; rm "$d/docs/design/tokens.json"
assert_exit 1 run "$d" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: 0 sources checked (docs/design/tokens.json missing)"
d="$(repo)"; printf '{"meta": {"name": "x", "version": 1, "source": "brief"}}\n' > "$d/docs/design/tokens.json"
assert_exit 1 run "$d" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: 0 sources checked (no meta.sourceHash in docs/design/tokens.json)"
t_end

t_begin "a symlinked docs/design/DESIGN.md hashes the root file it points to"
d="$(repo)"
ln -s ../../DESIGN.md "$d/docs/design/DESIGN.md"
assert_exit 0 run "$d" sh "$LINT" --hash docs/design/DESIGN.md
assert_eq "sha256:$(hex_of "$d/DESIGN.md")" "$T_OUT" "link hash equals root hash"
assert_exit 0 run "$d" DESIGN_SOURCE=docs/design/DESIGN.md sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: 1 source checked, docs/design/DESIGN.md matches tokens.json"
t_end

t_begin "tokens from the picked direction check approved.json, and fail once DESIGN.md carries tokens"
d="$(seeded)"
assert_exit 0 run "$d" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: 1 source checked, docs/design/variants/invite/approved.json matches tokens.json"
printf -- '---\nname: Invite\ndescription: Invite a teammate\ncolors:\n  primary: "#1f4e79"\n---\n# Invite\n' > "$d/DESIGN.md"
assert_exit 1 run "$d" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: DESIGN.md now carries frontmatter tokens; tokens.json was derived from docs/design/variants/invite/approved.json"
assert_contains "$T_OUT" "rerun design-system"
d="$(seeded)"
printf '{"round": 2}\n' > "$d/docs/design/variants/invite/approved.json"
assert_exit 1 run "$d" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: docs/design/variants/invite/approved.json is sha256:"
t_end

t_begin "runs with sh and awk only (no bash, python3 or node)"
d="$(repo)"
mp="$(minimal_path sh awk sed cat head sha256sum shasum openssl)"
assert_exit 0 run "$d" PATH="$mp" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: 1 source checked"
for tool in shasum openssl; do
  if command -v "$tool" >/dev/null 2>&1; then
    mp="$(minimal_path sh awk sed cat head "$tool")"
    assert_exit 0 run "$d" PATH="$mp" sh "$LINT" --sync
    assert_contains "$T_OUT" "design-sync: 1 source checked" "with $tool alone"
  fi
done
mp="$(minimal_path sh awk sed cat head)"
assert_exit 1 run "$d" PATH="$mp" sh "$LINT" --sync
assert_contains "$T_OUT" "design-sync: no sha256 tool (sha256sum, shasum or openssl)"
if command -v busybox >/dev/null 2>&1; then
  assert_exit 0 run "$d" busybox sh "$LINT" --sync
  assert_contains "$T_OUT" "design-sync: 1 source checked"
fi
t_end

t_begin "the schema records the hashed source, and the skill grants and names the check"
S="$KIT/plugins/bearing/skills/design-system"
got="$(python3 - "$S/templates/tokens.schema.json" <<'PY'
import json, sys
m = json.load(open(sys.argv[1]))["properties"]["meta"]
print(m["properties"]["sourceHash"]["pattern"])
print(m["properties"]["sourcePath"]["type"])
print(sorted(m["if"]["properties"]["source"]["enum"]), sorted(m["then"]["required"]))
PY
)"
assert_contains "$got" '^sha256:[0-9a-f]{64}$' "sourceHash pattern"
assert_contains "$got" "['approved-direction', 'design-md'] ['sourceHash', 'sourcePath']" "hashed sources require path and hash"
fm="$(sed -n '/^allowed-tools:/p' "$S/SKILL.md")"
assert_contains "$fm" "Bash(sh *skills/design-system/templates/design-lint.sh --hash *)" "hash grant"
assert_contains "$fm" "Bash(test:*)" "test grant"
assert_contains "$fm" "Bash(ln -sf ../../DESIGN.md docs/design/DESIGN.md)" "reversed link grant"
sk="$(cat "$S/SKILL.md")"
assert_contains "$sk" 'design-lint.sh" --hash <sourcePath>' "step 6 hash"
assert_contains "$sk" "sh scripts/design-lint.sh --sync" "design-sync target"
assert_contains "$sk" "ln -sf ../../DESIGN.md docs/design/DESIGN.md" "link reversed"
assert_contains "$sk" "test -e DESIGN.md" "root never clobbered"
ref="$(cat "$KIT/plugins/bearing/references/impeccable.md")"
assert_contains "$ref" "only when \`test -e DESIGN.md\`" "design-directions restore guarded"
assert_contains "$ref" "Scan stopped or failed before writing" "scan branch restores the link"
t_end

t_summary
