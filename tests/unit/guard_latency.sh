#!/usr/bin/env bash
# tests/unit/guard_latency.sh: the guard runs as a PreToolUse hook with a
# timeout, and a timed-out hook lets the command run. So the parse time is a
# security property: an 8000-byte command must be judged well inside the
# hook's 10 s timeout, and anything over the 16384-byte limit is refused
# before parsing. The limit is 3 s: bash 3.2 on a shared CI runner takes
# 1.2 to 1.9 s where bash 5 on a laptop takes 0.4 s, and 3 s still leaves
# more than a 3x margin to the timeout. Blocked
# strings are assembled at run time so the file never holds one on a line.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="sh"; P="pu$H"

pad_to() { # pad_to <text> <bytes>: repeat benign segments until the text is that long
  local s="$1" want="$2"
  local seg=" echo \"hello world\" 'x' && ls -la src | grep -n \$(date +%s) > /dev/null;"
  while [ "${#s}" -lt "$want" ]; do s="$s$seg"; done
  s="${s:0:$want}"
  printf '%s' "$s"
}
ms_now() { # milliseconds since the epoch; GNU date has %N, BSD date falls back to python3 or seconds
  local t
  t="$(date +%s%N 2>/dev/null)"
  case "$t" in *N|'') t="$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo "$(( $(date +%s) * 1000 ))")"; printf '%s' "$t";;
    *) printf '%s' "$((t / 1000000))";; esac
}
LIMIT_MS=3000
timed() { # timed <rc wanted> <what> <command string>: assert rc and under LIMIT_MS
  local t0 t1 el
  t0="$(ms_now)"
  assert_exit "$1" bash "$GUARD" command "$3"
  t1="$(ms_now)"; el=$((t1 - t0))
  assert_eq 1 "$([ "$el" -lt "$LIMIT_MS" ] && echo 1)" "$2 took ${el} ms (limit $LIMIT_MS)"
  echo "guard_latency: $2: ${#3} bytes, rc $T_RC, ${el} ms"
}

LC_ALL=C; export LC_ALL
benign="$(pad_to "true;" 8000)"
blocked="$(pad_to "true;" $((8000 - 10)))"; blocked="$blocked; git $P"
heredoc="bash <<'EOF'"
while [ "${#heredoc}" -lt 7990 ]; do heredoc="$heredoc
echo \"line with 'quotes'\" | grep x"; done
heredoc="${heredoc:0:7990}
EOF"

t_begin "inputs are the sizes they claim"
assert_eq 8000 "${#benign}" "benign length"
assert_eq 8000 "${#blocked}" "blocked length"
assert_contains "$blocked" "; git $P" "blocked ends with the verb"
t_end

t_begin "an 8000-byte command is judged in under 3 seconds"
timed 0 "benign" "$benign"
timed 2 "blocked" "$blocked"
assert_contains "$T_OUT" "blocked 'git $P'"
timed 0 "shell heredoc" "$heredoc"
t_end

t_begin "a command over the limit is refused before parsing"
over="$(pad_to "true;" 17000)"
assert_eq 17000 "${#over}" "over length"
timed 2 "over the limit" "$over"
assert_contains "$T_OUT" "command too long to check"
t_end

t_summary
