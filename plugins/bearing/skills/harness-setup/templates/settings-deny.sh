#!/usr/bin/env bash
# settings-deny.sh <mode>: refuse the shell commands this repository's
# .claude/settings.json denies, for a harness that cannot read that file.
# The list is .bearing/settings-denies.txt (written by harness-setup's
# harness_check.py extend); one entry per line, tab-separated:
#   deny   <words>   refuse a command whose words appear in this order
#                    (git -C . push matches "git push"; make -C . deploy
#                    matches "make deploy")
#   ask    <words>   Cursor asks; a harness that cannot ask from a hook refuses
#   path   <path>    refuse a command that names this file (cat .env)
# The command is split at ; & | ( ) ` quotes and newlines first, so
# bash -lc 'git push' and $(git push) are seen. A match inside an echo is
# refused too: over-refusing is the safe error. Anything unreadable (no jq,
# bad JSON, no command, no list) is refused: fail closed.
# <mode>: cursor (permission JSON on stdout), gemini, copilot, cline (their
# deny JSON), anything else (reason on stderr, exit 2: Codex, Claude, Kiro).
mode="${1:-exit2}"
here="$(cd "$(dirname "$0")/.." && pwd)"
list="$here/settings-denies.txt"

emit() { # emit <deny|ask|allow> <reason>
  local d="$1" r="$2" q
  if [ "$d" = allow ]; then [ "$mode" = cursor ] && printf '{"permission":"allow"}\n'; exit 0; fi
  q="$(printf '%s' "$r" | jq -R . 2>/dev/null || printf '"%s"' "$(printf '%s' "$r" | tr -d '"\\')")"
  case "$mode" in
    cursor)  printf '{"permission":"%s","user_message":%s,"agent_message":%s}\n' "$d" "$q" "$q"; exit 0;;
    gemini)  printf '{"decision":"deny","reason":%s}\n' "$q";;
    copilot) printf '{"permissionDecision":"deny","permissionDecisionReason":%s}\n' "$q";;
    cline)   printf '{"cancel":true,"errorMessage":%s}\n' "$q";;
    *)       printf '%s\n' "$r" >&2;;
  esac
  exit 2
}

j="$(cat)"
command -v jq >/dev/null 2>&1 || emit deny "settings-deny: jq is required; refusing (fail closed)"
cmd="$(printf '%s' "$j" | jq -r '
  (.command // .tool_input.command // .tool_input.cmd // .toolArgs.command // .tool_info.command_line // empty)
  | if type == "array" then join(" ") else tostring end' 2>/dev/null)"
[ -n "$cmd" ] || emit deny "settings-deny: could not read the command; refusing (fail closed)"
[ -r "$list" ] || emit deny "settings-deny: $list is missing; refusing (fail closed)"

segments="$(printf '%s\n' "$cmd" | tr ';&|()`"<>'"'" '\n\n\n\n\n\n\n  \n')"
verdict=allow; why=""
while IFS=$'\t' read -r kind words; do
  case "$kind" in deny|ask|path) ;; *) continue;; esac
  [ -n "$words" ] || continue
  read -r -a want <<<"$words"
  hit=0
  while IFS= read -r seg; do
    read -r -a toks <<<"$seg"
    if [ "$kind" = path ]; then
      p="${want[0]#./}"
      for t in "${toks[@]}"; do
        t="${t#./}"
        case "$t" in "$p"|*/"$p") hit=1; break;; esac
      done
    else
      n=0
      for t in "${toks[@]}"; do
        [ "$n" -eq 0 ] && t="${t##*/}"
        if [ "$t" = "${want[$n]}" ]; then n=$((n+1)); [ "$n" -eq "${#want[@]}" ] && { hit=1; break; }; fi
      done
    fi
    [ "$hit" -eq 1 ] && break
  done <<<"$segments"
  [ "$hit" -eq 1 ] || continue
  if [ "$kind" = ask ]; then
    [ "$verdict" = allow ] && { verdict=ask; why="'$words' asks for a person in .claude/settings.json"; }
  else
    verdict=deny; why="'$words' is denied in .claude/settings.json; a person runs it. Prepare and print the command instead."
    break
  fi
done <"$list"

if [ "$verdict" = ask ] && [ "$mode" != cursor ]; then
  verdict=deny; why="$why; this harness cannot ask from a hook, so it is refused"
fi
[ "$verdict" = allow ] && emit allow ""
emit "$verdict" "settings-deny: $why"
