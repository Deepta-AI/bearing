#!/usr/bin/env bash
# tests/lib/assert.sh: sourced by every test file. bash 3.2 safe (macOS).
#
#   t_begin <case>            open a named case (counted; a case that runs no
#   t_end                     assertion is a failure, so an empty test cannot pass)
#   t_run <cmd...>            run with $T_IN on stdin; sets T_RC and T_OUT (stdout+stderr)
#   assert_exit <rc> <cmd...> t_run and check the exit code
#   assert_eq <expected> <actual> [what]
#   assert_contains <haystack> <needle> [what]
#   assert_not_contains <haystack> <needle> [what]
#   assert_file <path> [mode]  the file exists (and has that octal mode)
#   tmpdir                    print a fresh directory, removed at exit
#   minimal_path <tool>...    print a PATH holding only those tools (symlinks)
#   t_summary                 print "<file>: N assertions, M failed" and exit
set -u
T_FILE="${T_FILE:-$0}"
T_RUN=0; T_FAIL=0; T_CASES=0; T_CASE=''; T_CASE_ASSERTS=0
T_IN=''; T_RC=0; T_OUT=''
T_TMPS=''
KIT="${KIT:-$(cd "$(dirname "$T_FILE")/../.." && pwd)}"
GUARD="$KIT/plugins/bearing/bin/brg-guard"

_t_fail() { T_FAIL=$((T_FAIL+1)); printf 'FAIL %s [%s]: %s\n' "${T_FILE##*/}" "$T_CASE" "$*" >&2; }
_t_pass() { :; }
_t_count() { T_RUN=$((T_RUN+1)); T_CASE_ASSERTS=$((T_CASE_ASSERTS+1)); }

t_begin() { T_CASE="$1"; T_CASES=$((T_CASES+1)); T_CASE_ASSERTS=0; }
t_end() {
  if [ "$T_CASE_ASSERTS" -eq 0 ]; then _t_fail "case ran no assertions"; fi
  T_CASE=''
}

t_run() {
  T_OUT="$(printf '%s' "$T_IN" | "$@" 2>&1)"; T_RC=$?
  return 0
}
assert_exit() {
  local want="$1"; shift
  _t_count
  t_run "$@"
  if [ "$T_RC" -eq "$want" ]; then _t_pass; else _t_fail "exit $T_RC, wanted $want: $* :: $(printf '%s' "$T_OUT" | head -c 160 | tr '\n' ' ')"; fi
}
assert_eq() {
  _t_count
  if [ "$1" = "$2" ]; then _t_pass; else _t_fail "${3:-values differ}: wanted [$1] got [$2]"; fi
}
assert_contains() {
  _t_count
  case "$1" in *"$2"*) _t_pass;; *) _t_fail "${3:-text} does not contain [$2]: $(printf '%s' "$1" | head -c 200 | tr '\n' ' ')";; esac
}
assert_not_contains() {
  _t_count
  case "$1" in *"$2"*) _t_fail "${3:-text} contains [$2]: $(printf '%s' "$1" | head -c 200 | tr '\n' ' ')";; *) _t_pass;; esac
}
assert_file() {
  local mode
  _t_count
  if [ ! -e "$1" ]; then _t_fail "missing file $1"; return 0; fi
  if [ -n "${2:-}" ]; then
    mode="$(stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1" 2>/dev/null)"
    [ "$mode" = "$2" ] || { _t_fail "$1 has mode $mode, wanted $2"; return 0; }
  fi
  _t_pass
}

tmpdir() {
  local d base="${TMPDIR:-/tmp}"
  # macOS sets TMPDIR with a trailing slash; a doubled slash would make the
  # paths tests expect differ from the ones the code under test prints.
  base="${base%/}"
  d="$(mktemp -d "${base:-/tmp}/brg-test.XXXXXX")"
  T_TMPS="$T_TMPS $d"
  printf '%s' "$d"
}
_t_cleanup() { [ -z "$T_TMPS" ] || rm -rf $T_TMPS; }
trap _t_cleanup EXIT

minimal_path() { # minimal_path <tool>...: a directory of symlinks to exactly these tools
  local d t p
  d="$(tmpdir)"
  for t in "$@"; do
    p="$(command -v "$t" 2>/dev/null || true)"
    [ -n "$p" ] || continue
    ln -s "$p" "$d/$t"
  done
  printf '%s' "$d"
}

t_summary() {
  if [ "$T_RUN" -eq 0 ]; then _t_fail "no assertions ran"; fi
  printf '%s: %d cases, %d assertions, %d failed\n' "${T_FILE##*/}" "$T_CASES" "$T_RUN" "$T_FAIL"
  [ "$T_FAIL" -eq 0 ] && [ "$T_RUN" -gt 0 ] || exit 1
  exit 0
}
