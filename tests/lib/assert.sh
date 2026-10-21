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
#   hook_kit <PATH>           print a copy of the bearing plugin whose hooks (lib.sh and
#                             brg-guard) set PATH to <PATH> instead of the fixed directories;
#                             the one seam for a test that watches or removes a tool;
#                             removed at exit; a caller fails when it prints nothing
#   replace_in <file> <old> <new>  replace one literal occurrence in a fixture (python3,
#                             which every CI image has; perl and GNU sed -i are not portable);
#                             fails unless old occurs exactly once
#   t_summary                 print "<file>: N assertions, M failed" and exit
set -u
# A test that runs git in a temp folder must not reach a repository named by
# the caller's environment (a git hook from a linked worktree exports these).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE GIT_PREFIX
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

replace_in() {
  python3 - "$1" "$2" "$3" <<'PY' || { echo "replace_in: $2 does not occur exactly once in $1" >&2; return 1; }
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
text = open(path).read()
if text.count(old) != 1:
    sys.exit(1)
open(path, "w").write(text.replace(old, new))
PY
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

# hook_kit runs in $(...), where a tmpdir it made would never reach T_TMPS,
# so every copy goes under T_KITS, made here in the test's own shell (not
# through $(tmpdir), whose T_TMPS line would be lost the same way) and
# removed at exit with the rest.
T_KITS="${TMPDIR:-/tmp}"; T_KITS="${T_KITS%/}"
T_KITS="$(mktemp -d "${T_KITS:-/tmp}/brg-kits.XXXXXX")" && T_TMPS="$T_TMPS $T_KITS"
hook_kit() { # hook_kit <PATH>: a plugin copy whose hooks reset PATH to <PATH>
  local k line
  [ -d "$T_KITS" ] || return 1
  k="$(mktemp -d "$T_KITS/kit.XXXXXX")" || return 1
  cp -R "$KIT/plugins/bearing/." "$k/" || return 1
  # the hook PATH line, read from lib.sh (brg-guard holds the same line)
  line="$(grep '^PATH=' "$KIT/plugins/bearing/hooks/scripts/lib.sh" | head -1)"
  [ -n "$line" ] || return 1
  replace_in "$k/hooks/scripts/lib.sh" "$line" "PATH='$1'; export PATH" || return 1
  replace_in "$k/bin/brg-guard" "$line" "PATH='$1'; export PATH" || return 1
  printf '%s' "$k"
}

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

# mk: run make with SHELL set to the bash running the tests. The Makefiles pin
# SHELL := /bin/bash, which does not exist in the bash:3.2 image; a command-line
# variable overrides it.
BASH_PATH="$(command -v bash)"
mk() { make SHELL="$BASH_PATH" "$@"; }
