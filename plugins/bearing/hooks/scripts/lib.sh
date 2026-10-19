#!/usr/bin/env bash
# Shared helpers for Bearing hook scripts. Sourced, not executed.
#
# Hooks run outside the sandbox with the harness's environment, so the first
# thing done is to drop what in it could run another program: PATH becomes
# /usr/bin:/bin plus the system tool directories (jq, git and python3 on
# macOS live under /usr/local/bin or /opt/homebrew/bin; on Linux under
# Linuxbrew or a Nix profile), never a directory the environment put first
# (brg-doctor checks the BRG_HOOK_TOOLS below resolve on it, reading both
# lines from lib.sh, and the settings template denies Edit and Write on the
# user-owned ones); BASH_ENV and ENV (sourced by every bash started
# later), CDPATH (redirects cd), PYTHON* (python3 also runs -I everywhere),
# LD_* and DYLD_* (preloaded libraries) are unset. BASH_ENV in the harness's
# own environment is sourced by bash before this line runs, which no script
# can prevent; the settings template denies Edit and Write on the settings
# files whose env could set it.
PATH=/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin:/home/linuxbrew/.linuxbrew/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin; export PATH
BRG_HOOK_TOOLS='jq python3 git bash'
# An entry script execs the next with "$BASH" (no PATH lookup); execfail
# makes a failed exec return, so the script exits 2 (fail closed) instead
# of ending with 126 or 127, which the harness reads as "let it through".
shopt -s execfail
unset BASH_ENV ENV CDPATH
for _brg_v in $(compgen -e 2>/dev/null); do
  case "$_brg_v" in (PYTHON*|LD_*|DYLD_*) unset "$_brg_v" 2>/dev/null ;; esac
done
unset _brg_v

# Every hook reads one JSON object on stdin. We read it once into $HOOK_JSON
# and pull fields with jq. jq is required: without it a field cannot be read
# reliably, so json_field prints the sentinel __BRG_UNPARSED__ and the guard
# treats a command it cannot read as blocked (fail closed). The other
# subcommands (format, task-id, session, stop) are hints, not safety
# controls, and simply do nothing on the sentinel.

# Hooks run outside the sandbox, and git runs programs the repository names:
# core.fsmonitor whenever it reads the index, hooks under core.hooksPath (or
# .git/hooks) when status refreshes the index, a filter driver's clean or
# process command for every file .gitattributes or .git/info/attributes
# gives filter=<name> when status re-reads its content, diff.external and the
# pager (core.pager, pager.<command>), and gpg.program when log.showSignature
# is on. git_lockdown turns every one of them off for each git a hook starts,
# here or in a script it calls (brg-session, brg-changed, progress.py): git
# hands -c settings to its children through GIT_CONFIG_PARAMETERS, and the
# last setting wins. A filter cannot be turned off by pattern, only by name,
# so each driver any config file in force defines (git config follows its
# includes) gets an empty clean, smudge and process; an empty command is no
# filter. The names go in git's quoted 'key'='value' form, which takes a
# quote or an equals sign in a name. GIT_PAGER=cat outranks every pager
# setting. A submodule's own drivers are not listed here: the hooks' git
# status runs with --ignore-submodules=dirty, which never starts a git in a
# submodule. brg-guard holds the same function (it runs where lib.sh is not).
git_lockdown() {
  local p k n nl='
' seen='
' q="'\\''"
  p="'core.fsmonitor=false' 'core.hooksPath=/dev/null' 'core.pager=cat' 'diff.external=' 'log.showSignature=false'"
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    n="${k#filter.}"; n="${n%.*}"
    case "$seen" in (*"$nl$n$nl"*) continue ;; esac
    seen="$seen$n$nl"
    n=${n//\'/$q}
    p="$p 'filter.$n.clean'='' 'filter.$n.smudge'='' 'filter.$n.process'='' 'filter.$n.required'='false'"
  done <<EOF
$(git config --name-only --get-regexp '^filter\..*\.(clean|smudge|process)$' 2>/dev/null)
EOF
  # shellcheck disable=SC2089,SC2090 # the quotes are git's own format, kept literally
  export GIT_CONFIG_PARAMETERS="${GIT_CONFIG_PARAMETERS:+$GIT_CONFIG_PARAMETERS }$p"
  export GIT_PAGER=cat
  unset GIT_EXTERNAL_DIFF
}
# The Bash guard runs no git; every other hook script is locked down here.
case "${0##*/}" in (block-publish.sh) ;; (*) git_lockdown ;; esac

HOOK_JSON="$(cat 2>/dev/null || true)"
BEARING_JQ_WARNED=0

json_field() {
  # json_field <dot.path>   e.g. json_field tool_input.command
  local path="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$HOOK_JSON" | jq -r ".${path} // empty" 2>/dev/null
  else
    if [ "$BEARING_JQ_WARNED" -eq 0 ]; then
      echo "bearing: jq not found in $PATH; run brg-doctor" >&2
      BEARING_JQ_WARNED=1
    fi
    printf '%s' "__BRG_UNPARSED__"
  fi
}

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null
}

current_branch() {
  git branch --show-current 2>/dev/null
}

# Task id convention: an upper-case prefix, a dash, digits (TASK-142, PROJ-7).
task_id_from_branch() {
  current_branch | grep -oE '[A-Z][A-Z0-9]*(-[0-9]+)+' | head -1
}

state_file() {
  local root branch
  root="$(repo_root)" || return 1
  branch="$(current_branch)" || return 1
  [ -n "$root" ] && [ -n "$branch" ] || return 1
  printf '%s/.bearing/state/%s.md' "$root" "$(printf '%s' "$branch" | tr '/' '_')"
}

# block_or_print <guard> <subcommand> [args...]: run a guard subcommand whose
# exit 2 means "send Claude back with this reason" (stop-gate).
# Exit 2 becomes {"decision": "block", "reason": <stderr>} on stdout; any
# other result prints what the guard printed. Without jq the guard's own
# exit 2 and stderr pass through, which Claude Code also reads as a block.
block_or_print() {
  local err out rc
  err="$(mktemp)"
  out="$("$BASH" "$@" 2>"$err")"; rc=$?
  if [ "$rc" -eq 2 ]; then
    if command -v jq >/dev/null 2>&1; then
      jq -n --arg r "$(cat "$err")" '{decision: "block", reason: $r}'
      rm -f "$err"; return 0
    fi
    cat "$err" >&2; rm -f "$err"; exit 2
  fi
  [ -n "$out" ] && printf '%s\n' "$out"
  rm -f "$err"; return 0
}
