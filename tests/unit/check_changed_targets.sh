#!/usr/bin/env bash
# tests/unit/check_changed_targets.sh: every stack Makefile template has a
# check-changed target that prints its counts, never writes .check-passed,
# and writes .check-changed-passed, also when no changed file is its kind
# (else a README edit holds the Stop gate on every turn). A skipped gate
# never writes the marker. Then end to end with stub tools: a README-only
# edit clears the Stop gate (Go), a missing golangci-lint leaves the marker
# unwritten (Go), and pytest finding no tests is a pass (Python). Full
# toolchain runs are in the scaffold job.
set -u
. "$(dirname "$0")/../lib/assert.sh"
n=0
seen=""
for mk in $(cd "$KIT" && git ls-files 'plugins/*/skills/*/templates*/Makefile'); do
  grep -q 'check-passed' "$KIT/$mk" || continue
  n=$((n+1))
  body="$(awk '/^check-changed:/{p=1;print;next} p&&/^[^\t]/{exit} p' "$KIT/$mk")"
  t_begin "$mk"
  assert_contains "$body" "check-changed:" "target present"
  assert_contains "$body" "0 files, nothing to check" "empty case"
  assert_contains "$body" ".check-changed-passed" "writes its own marker"
  assert_not_contains "$body" "/.check-passed" "never writes the full marker"
  assert_contains "$body" "packages checked" "prints its count"
  zero="$(printf '%s\n' "$body" | grep '0 files, nothing to check')"
  assert_contains "$zero" ".check-changed-passed" "the no-relevant-files branch writes the marker"
  case "$body" in *"golangci-lint missing"*)
    assert_contains "$body" "a gate was skipped, marker not written" "a missing linter is a skipped gate";;
  esac
  case "$body" in *pytest*)
    assert_contains "$body" "-eq 5" "pytest exit 5 (no tests collected) is handled";;
  esac
  t_end
  seen="$seen
$(grep '^CHANGED = ' "$KIT/$mk" | cksum | cut -d' ' -f1)"
done
t_begin "CHANGED variable identical"
assert_eq 1 "$(printf '%s\n' "$seen" | grep . | sort -u | wc -l | tr -d ' ')" "one distinct CHANGED line across $n templates"
t_end
t_begin "templates found"
assert_eq 13 "$n" "stack Makefile templates with a check marker"
t_end

# A throwaway repository holding one template's Makefile, committed, with a
# session start mark older than every edit.
new_repo() { # new_repo <template Makefile>
  local r
  r="$(tmpdir)"
  git -C "$r" init -q -b main
  printf '.bearing/state/\n' > "$r/.gitignore"
  cp "$KIT/$1" "$r/Makefile"; printf '# x\n' > "$r/README.md"
  git -C "$r" add -A; git -C "$r" -c user.email=t@example.com -c user.name=t commit -q -m init
  mkdir -p "$r/.bearing/state"; : > "$r/.bearing/state/.session-S1"
  touch -t 202001010000 "$r/.bearing/state/.session-S1"
  printf '%s' "$r"
}
stubs="$(tmpdir)"
for t in go gofmt; do printf '#!/usr/bin/env bash\ncase "$1" in list) echo example.com/x;; esac\nexit 0\n' > "$stubs/$t"; chmod 755 "$stubs/$t"; done
printf '#!/usr/bin/env bash\ncase "$*" in *pytest*) echo "no tests ran"; exit 5;; esac\nexit 0\n' > "$stubs/uv"; chmod 755 "$stubs/uv"
base="$(minimal_path bash git sed grep head tail tr wc cat dirname basename mktemp rm mkdir ls awk env printf make sort xargs touch)"

t_begin "go: a README-only edit passes check-changed and clears the Stop gate"
r="$(new_repo plugins/bearing-backend/skills/go/templates/Makefile)"
printf '# changed\n' > "$r/README.md"
( cd "$r" && bash "$GUARD" stop-gate --id S1 ) >/dev/null 2>&1; assert_eq 2 "$?" "blocked before the check"
T_OUT="$(cd "$r" && PATH="$stubs:$base" make -s check-changed 2>&1)"; assert_eq 0 "$?" "check-changed exits 0"
assert_contains "$T_OUT" "0 files, nothing to check"
assert_file "$r/.bearing/state/.check-changed-passed"
( cd "$r" && bash "$GUARD" stop-gate --id S1 ) >/dev/null 2>&1; assert_eq 0 "$?" "stop-gate passes after check-changed"
t_end

t_begin "go: golangci-lint missing is a skipped gate, marker not written"
r="$(new_repo plugins/bearing-backend/skills/go/templates/Makefile)"
mkdir -p "$r/pkg"; printf 'package pkg\n' > "$r/pkg/a.go"
T_OUT="$(cd "$r" && PATH="$stubs:$base" make -s check-changed 2>&1)"; assert_eq 0 "$?" "check-changed exits 0"
assert_contains "$T_OUT" "golangci-lint missing, lint not run"
assert_contains "$T_OUT" "a gate was skipped, marker not written"
[ -f "$r/.bearing/state/.check-changed-passed" ]; assert_eq 1 "$?" "no marker after a skipped gate"
t_end

for tpl in python/templates python/templates-cli data-pipeline/templates; do
  t_begin "$tpl: pytest collecting no tests (exit 5) is a pass"
  r="$(new_repo "plugins/bearing-backend/skills/$tpl/Makefile")"
  mkdir -p "$r/tests"; printf 'def test_x():\n    pass\n' > "$r/tests/test_slow.py"
  T_OUT="$(cd "$r" && PATH="$stubs:$base" make -s check-changed 2>&1)"; assert_eq 0 "$?" "check-changed exits 0"
  assert_contains "$T_OUT" "1 files, 0 packages checked"
  assert_file "$r/.bearing/state/.check-changed-passed"
  t_end
done
t_summary
