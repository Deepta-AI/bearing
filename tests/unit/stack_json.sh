#!/usr/bin/env bash
# tests/unit/stack_json.sh: every skills/*/templates*/stack.json parses,
# carries the keys brg-scaffold and brg-adopt require (id type stack databases
# entrypoint rules_file install tool), has a lane-shaped id that the scaffold
# lists as known, a unique id, a rules_file ending in .md backed by the
# skill's references/rules.md, a non-empty tool, and a Makefile with a check
# target beside it. Fails when zero stack.json files are found.
set -u
. "$(dirname "$0")/../lib/assert.sh"

# jget <file> <key>: the string value, or empty when absent or not a string.
jget() { python3 -c 'import json,sys
v=json.load(open(sys.argv[1])).get(sys.argv[2],"")
print(v if isinstance(v,str) else "")' "$1" "$2"; }

files="$(ls "$KIT"/skills/*/templates*/stack.json 2>/dev/null | sort)"
n=0; ids=""

t_begin "the scaffold lists every id as known"
assert_exit 2 bash "$KIT/bin/brg-scaffold" no-such-stack Probe --dir "$(tmpdir)/x"
assert_contains "$T_OUT" "unknown stack 'no-such-stack'. Known:"
known="$T_OUT"
t_end

for f in $files; do
  n=$((n+1))
  rel="${f#"$KIT"/}"
  skill="$(basename "$(dirname "$(dirname "$f")")")"
  t_begin "$rel"
  assert_exit 0 python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$f"
  for k in id type stack databases entrypoint rules_file install tool; do
    _t_count
    python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if sys.argv[2] in d else 1)' "$f" "$k" \
      || _t_fail "$rel lacks key '$k'"
  done
  for k in id type stack databases entrypoint rules_file tool; do
    assert_eq 1 "$([ -n "$(jget "$f" "$k")" ] && echo 1)" "$rel: '$k' is a non-empty string"
  done
  id="$(jget "$f" id)"
  assert_eq 1 "$(printf '%s' "$id" | grep -Eq '^[a-z][a-z0-9-]*$' && echo 1)" "$rel: id '$id' is a lane name (lower-case, digits, dashes)"
  assert_contains "$known" " $id " "brg-scaffold knows '$id'"
  case " $ids " in *" $id "*) _t_count; _t_fail "duplicate stack id '$id' in $rel";; esac
  ids="$ids $id"
  rules="$(jget "$f" rules_file)"
  assert_eq 1 "$([ "${rules%.md}" != "$rules" ] && echo 1)" "$rel: rules_file '$rules' ends in .md"
  assert_file "$KIT/skills/$skill/references/rules.md"
  assert_file "$(dirname "$f")/Makefile"
  assert_eq 1 "$(grep -Eq '^check:' "$(dirname "$f")/Makefile" 2>/dev/null && echo 1)" "$rel: the stack Makefile has a check target"
  t_end
done

t_begin "count"
assert_eq 1 "$([ "$n" -gt 0 ] && echo 1)" "at least one stack.json (found $n)"
t_end

echo "stack_json: $n stack files (ids:$ids)"
t_summary
