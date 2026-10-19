#!/usr/bin/env bash
# tests/unit/hook_env.sh: hooks run outside the sandbox with the harness's
# environment. Once lib.sh (or brg-guard) starts, PATH is /usr/bin:/bin plus
# the trusted tool directories, and BASH_ENV, ENV, CDPATH, PYTHON*, LD_* and
# DYLD_* are gone, so no later bash sources an agent's script, no tool comes
# from a directory the agent put first on PATH, and every python3 runs -I.
# BASH_ENV is still sourced by the harness's own bash before the first line of
# the entry script (outside Bearing's reach; the settings denies close the
# agent's route to it), so the canary records which script sourced it and only
# a nested one counts. Canary files prove nothing ran. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
HS="$KIT/plugins/bearing/hooks/scripts"
REALBASH="$(command -v bash)"
canary="$(tmpdir)"
newrepo() { # repo: a Bearing repository on feature/ABC-1-thing with a next step recorded
  repo="$(tmpdir)"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  printf '.bearing/state/\n' > "$repo/.gitignore"
  printf 'check:\n\t@true\n' > "$repo/Makefile"
  printf 'a\n' > "$repo/f.txt"
  git -C "$repo" add .gitignore Makefile f.txt; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" switch -q -c feature/ABC-1-thing
  mkdir -p "$repo/.bearing/state" "$repo/docs/progress"
  printf 'Next: run the tests\n' > "$repo/.bearing/state/feature_ABC-1-thing.md"
}
input() { # input <hook>: the JSON each hook reads
  case "$1" in
    (stop-summary.sh) printf '%s' '{"session_id":"s1","stop_hook_active":false}' ;;
    (*) printf '%s' '{"session_id":"s1","source":"startup"}' ;;
  esac
}
HOOKS="session-start.sh stop-summary.sh session-end.sh"

t_begin "BASH_ENV is sourced by no bash a hook starts"
newrepo
printf 'printf "%%s\\n" "${0##*/}" >> "%s/bash-env"\n' "$canary" > "$canary/benv.sh"
n=0
for h in $HOOKS; do
  : > "$canary/bash-env"
  input "$h" > "$canary/in"
  ( cd "$repo" && BASH_ENV="$canary/benv.sh" ENV="$canary/benv.sh" HOME="$repo/home" "$REALBASH" "$HS/$h" < "$canary/in" ) >/dev/null 2>&1
  # The entry script's own bash sources it before line 1 (the harness's route);
  # every other line is a nested bash after lib.sh started.
  assert_eq "$h" "$(sort -u "$canary/bash-env" | tr '\n' ' ' | sed 's/ $//')" "$h: only the entry bash sourced BASH_ENV"
  n=$((n+1))
done
assert_eq 3 "$n" "hooks exercised"
t_end

t_begin "a tool first on PATH never runs from a hook"
newrepo
pbin="$(tmpdir)"; tools="jq git python3 python bash sh cat dirname sed grep tr head date mktemp env awk cut wc tail mv rm mkdir find touch ls"
for t in $tools; do
  real="$(command -v "$t" 2>/dev/null)" || continue
  printf '#!/bin/sh\n: > "%s/path-%s"\nexec "%s" "$@"\n' "$canary" "$t" "$real" > "$pbin/$t"; chmod 755 "$pbin/$t"
done
rm -f "$canary"/path-*
n=0
for h in $HOOKS; do
  input "$h" > "$canary/in"
  ( cd "$repo" && PATH="$pbin:$PATH" HOME="$repo/home" "$REALBASH" "$HS/$h" < "$canary/in" ) >/dev/null 2>&1
  assert_eq "" "$(find "$canary" -name 'path-*' | sed 's#.*/path-##' | sort | tr '\n' ' ')" "$h: no tool came from the planted directory"
  rm -f "$canary"/path-*
  n=$((n+1))
done
assert_eq 3 "$n" "hooks exercised"
t_end

t_begin "PYTHON*, LD_* and CDPATH from the environment reach no python3 or cd a hook runs"
newrepo
py="$(tmpdir)"
printf 'open("%s/pythonpath", "w").close()\n' "$canary" > "$py/sitecustomize.py"
printf 'open("%s/pythonstartup", "w").close()\n' "$canary" > "$py/startup.py"
mkdir -p "$py/cd/.bearing" "$py/cd/state"
n=0
for h in $HOOKS; do
  input "$h" > "$canary/in"
  ( cd "$repo" && PYTHONPATH="$py" PYTHONSTARTUP="$py/startup.py" PYTHONINSPECT=1 \
      LD_LIBRARY_PATH="$py" CDPATH="$py/cd" HOME="$repo/home" "$REALBASH" "$HS/$h" < "$canary/in" ) >/dev/null 2>&1
  assert_eq "" "$(find "$canary" -name 'python*' | sed 's#.*/##' | sort | tr '\n' ' ')" "$h: no python3 read PYTHON* variables"
  rm -f "$canary"/python*
  n=$((n+1))
done
assert_eq 3 "$n" "hooks exercised"
# session-end reached progress.py (the python3 the -I rule is about)
assert_file "$repo/docs/progress/ABC-1.md"
t_end

t_begin "lib.sh and brg-guard reset the environment at the top"
lib="$(cat "$HS/lib.sh")"
for v in BASH_ENV ENV CDPATH; do assert_contains "$lib" "$v" "lib.sh unsets $v"; done
assert_contains "$lib" "PATH=/usr/bin:/bin:" "lib.sh sets PATH from /usr/bin:/bin"
assert_contains "$(head -20 "$GUARD")" "PATH=/usr/bin:/bin:" "brg-guard sets PATH at the top"
# every python3 a hook script or brg-guard runs is isolated (-I)
bad="$(grep -n 'python3 ' "$HS"/*.sh "$GUARD" "$KIT/plugins/bearing/bin/brg-changed" "$KIT/plugins/bearing/bin/brg-session" \
  | grep -v '^[^:]*:[0-9]*: *#' | grep -v 'command -v python3' | grep -v 'python3 -I' | grep -v '# a bare PATH' || true)"
assert_eq "" "$bad" "python3 without -I"
# no entry script runs a program before lib.sh resets the environment
n=0
for f in "$HS"/*.sh; do
  [ "${f##*/}" = lib.sh ] && continue
  first="$(grep -v '^#' "$f" | grep -v '^set -u$' | grep -v '^ *$' | head -1)"
  assert_not_contains "$first" '$(' "${f##*/}: the line before lib.sh runs no program"
  n=$((n+1))
done
assert_eq 1 "$([ "$n" -ge 8 ] && echo 1)" "entry scripts checked ($n)"
t_end

t_summary
