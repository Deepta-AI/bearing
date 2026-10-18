#!/usr/bin/env bash
# Shared helpers for the committed git hooks. Sourced by each hook.
# shellcheck disable=SC2034  # the policy variables are read by the hooks
set -u

# Repository policy. The defaults are the kit standard. In a repository with
# its own CONTRIBUTING, ADRs or branch protection, set these from those
# documents when the hooks are installed: a hook that rejects what the team's
# own rules allow gets bypassed with --no-verify, and then it checks nothing.
COMMIT_TYPES='feat|fix|refactor|test|docs|chore|perf|build|ci|revert'
BRANCH_PREFIXES='feature|bugfix|hotfix|chore|docs|release'
PROTECTED_BRANCHES='main master develop'  # never pushed to or deleted from a clone
MAX_FILE_KB=5120        # staged file size limit in KiB (1 MB = 1024); 0 turns it off
BODY_MAX=100            # longest commit body line; 0 turns it off
NO_EM_DASH=1            # em dash refused in commit messages and staged prose
NO_AI_TRAILER=1         # AI co-author and "generated with" trailers refused
# Push confirmation. tty: a person types the branch name on a terminal, so a
#   push from an IDE or GUI client (no terminal) is refused. agents: refused
#   only when a coding agent's environment is detected. off: none.
PUSH_CONFIRM='tty'
GATE_CMD='make check'   # the full gate pre-push runs once

hook_fail() { printf 'hook %s: %s\n' "${HOOK_NAME:-?}" "$*" >&2; exit 1; }
hook_note() { printf 'hook %s: %s\n' "${HOOK_NAME:-?}" "$*"; }

# The em dash as bytes, so no hook file contains the character itself.
EM_DASH="$(printf '\342\200\224')"

# Task id: an upper-case prefix, then one or more dash-number groups, in
# whatever shape the configured tracker uses: PREFIX-123, PREFIX-00-017.
TASK_ID_RE='[A-Z][A-Z0-9]*(-[0-9]+)+'
# feature/PREFIX-123-ShortName, release/v1.2.3
BRANCH_RE="^(${BRANCH_PREFIXES})/(${TASK_ID_RE}-[A-Za-z0-9]+|v[0-9]+\.[0-9]+\.[0-9]+)$"
COMMIT_RE="^(${COMMIT_TYPES})(\([a-z0-9._/-]+\))?!?: .{1,72}( \[${TASK_ID_RE}\])?$"
AI_TRAILER_RE='^(Co-Authored-By|Co-authored-by): .*(Claude|Anthropic|Copilot|ChatGPT|Gemini|Cursor|Devin)|^(Generated with|🤖 Generated)'

# task_of <branch>: the task id a branch name carries, or nothing.
task_of() { printf '%s' "$1" | grep -oE "$TASK_ID_RE" | head -1; }

# is_protected <branch>
is_protected() { case " $PROTECTED_BRANCHES " in *" $1 "*) return 0;; esac; return 1; }

# url_key <url>: <host>/<path> for a git URL, so an ssh, scp-style or https
# spelling of one repository gives one key: scheme, user and password
# dropped, host lower-cased, leading slashes, a trailing slash and .git
# removed. ssh://git@host:22/group/repo.git, git@host:group/repo.git and
# https://host/group/repo all give host/group/repo. A port other than the
# scheme's default (ssh 22, https 443) stays: ssh://git@host:2222/g/r gives
# host:2222/g/r. Only ssh://, scp-style and https:// are keyed: http://,
# git://, any other scheme and a <helper>::<address> form exit 1, as do a
# relative path and no path. A local path or file:// URL gives
# localhost/<path> (the form tests use; no agent pushes to one in practice).
url_key() {
  local u="$1" h p port="" dport
  case "$u" in
    (*::*) return 1 ;;
    (file://*) h=localhost; p="${u#file://}" ;;
    (ssh://*|https://*)
      case "$u" in (ssh://*) dport=22;; (*) dport=443;; esac
      u="${u#*://}"; h="${u%%/*}"; [ "$h" != "$u" ] || return 1
      p="${u#"$h"}"; h="${h##*@}"
      case "$h" in (*:*) port="${h##*:}"; h="${h%:*}";; esac
      case "$port" in (*[!0-9]*) return 1;; esac
      [ "$port" != "$dport" ] || port="" ;;
    (*://*) return 1 ;;
    (/*) h=localhost; p="$u" ;;
    (*:*) h="${u%%:*}"; case "$h" in (*/*) return 1;; esac
          p="${u#*:}"; h="${h##*@}" ;;
    (*) return 1 ;;
  esac
  case "$h" in (''|*[!A-Za-z0-9.-]*) return 1;; esac
  h="$(printf '%s' "$h" | tr 'A-Z' 'a-z')"
  while :; do case "$p" in (/*) p="${p#/}";; (*/) p="${p%/}";; (*) break;; esac; done
  p="${p%.git}"
  [ -n "$p" ] || return 1
  printf '%s%s/%s\n' "$h" "${port:+:$port}" "$p"
}

# The one GIT_CONFIG_PARAMETERS an agent push accepts: what git exports to
# the hook when brg-push run pins its transport with
# `git -c core.sshCommand=ssh -c core.hooksPath=.githooks push` (git 2.31 or
# later spells it this way; an older git is refused).
BRG_PUSH_PARAMS="'core.sshCommand'='ssh' 'core.hooksPath'='.githooks'"

# transport_redirect: prints the first variable or git setting that can send
# this push somewhere other than the URL auto_push_allowed judges, or returns
# 1 when there is none. Environment: GIT_SSH, GIT_SSH_COMMAND,
# GIT_PROXY_COMMAND, GIT_CONFIG_COUNT and GIT_CONFIG_PARAMETERS (except
# BRG_PUSH_PARAMS), when set at all. Effective config: core.sshCommand other
# than ssh, core.hooksPath other than .githooks, a non-empty core.gitProxy,
# http(s).proxy, http.<url>.proxy, remote.origin.proxy or remote.origin.vcs, an
# http.sslVerify that is false, and any url.<base>.insteadOf or pushInsteadOf
# whose prefix matches a remote.origin.url.
transport_redirect() {
  local v n val o u
  for v in GIT_SSH GIT_SSH_COMMAND GIT_PROXY_COMMAND GIT_CONFIG_COUNT GIT_CONFIG_PARAMETERS; do
    [ -n "${!v+x}" ] || continue
    [ "$v" = GIT_CONFIG_PARAMETERS ] && [ "${!v}" = "$BRG_PUSH_PARAMS" ] && continue
    printf '%s\n' "$v"; return 0
  done
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    case "$n" in
      (core.sshcommand) [ "$(git config --get "$n")" != ssh ] || continue ;;
      (core.hookspath) [ "$(git config --get "$n")" != .githooks ] || continue ;;
      (*.sslverify) [ "$(git config --bool --get "$n" 2>/dev/null)" = false ] || continue ;;
      (url.*) o=1
        while IFS= read -r val; do
          while IFS= read -r u; do
            case "$u" in ("$val"*) o=0;; esac
          done <<EOF
$(git config --get-all remote.origin.url)
EOF
        done <<EOF
$(git config --get-all "$n")
EOF
        [ "$o" -eq 0 ] || continue ;;
      (*) [ -n "$(git config --get "$n")" ] || continue ;;
    esac
    printf '%s\n' "$n"; return 0
  done <<EOF
$(git config --name-only --get-regexp '^(core\.(sshcommand|gitproxy|hookspath)|https?\.(.*\.)?proxy|http\.(.*\.)?sslverify|remote\.origin\.(proxy|vcs)|url\..*\.(push)?insteadof)$' 2>/dev/null | sort -u)
EOF
  return 1
}

# passwd_home: the current user's home directory from the passwd entry, not
# from $HOME, which whoever runs git controls. Portable (no getent): tilde
# expansion of a validated user name, and the directory must belong to the
# effective user.
passwd_home() {
  local u h
  u="$(id -un 2>/dev/null)" || return 1
  case "$u" in (''|[-+]*|*[!A-Za-z0-9._-]*) return 1;; esac
  eval "h=~$u"
  case "$h" in (''|'~'*) return 1;; esac
  [ -d "$h" ] && [ -O "$h" ] || return 1
  printf '%s\n' "$h"
}

# auto_push_allowed <remote> <url>: exit 0 when this push (pre-push's $1 and
# $2) may go out as an agent's opted-in push. The remote must be origin, with
# no pushurl that differs from its url, and url_key of the URL git is pushing
# to must be an entry of BEARING_AUTO_PUSH (<host>/<path>, space or comma
# separated, quotes optional) in <passwd home>/.config/bearing/bearing.env.
# The transport is bound as well as the destination: any setting
# transport_redirect names refuses, so the URL judged is the host the push
# reaches. pre-push calls it only with an agent variable set, so BEARING_ENV,
# XDG_CONFIG_HOME, HOME and an exported BEARING_AUTO_PUSH are never read: the
# agent controls its own environment. On refusal AUTO_WHY says why.
# The limit: this hook runs in the pusher's environment. brg-push run (the
# Stop hook's push) runs git with a cleared environment, keeping only
# PATH=/usr/bin:/bin, HOME from the passwd entry, the agent variable and
# SSH_AUTH_SOCK, and pins `-c core.sshCommand=ssh -c core.hooksPath=.githooks`,
# so what the hook judges there is what goes out. A push an agent runs by
# other means keeps the agent's PATH, exported shell functions and tools
# (an ssh earlier on PATH, a wrapped git), and an agent able to write the
# bearing.env file (outside the sandbox) can opt in. For those the guard rows
# that deny an agent's git push and writes to ~/.config/bearing are the wall.
AUTO_WHY=""
auto_push_allowed() {
  local home envf line v key x pu ok=1
  [ "$1" = origin ] || { AUTO_WHY="the remote is $1, not origin"; return 1; }
  pu="$(git config --get-all remote.origin.pushurl 2>/dev/null)"
  if [ -n "$pu" ] && [ "$pu" != "$(git config --get remote.origin.url 2>/dev/null)" ]; then
    AUTO_WHY="origin has a pushurl that differs from its url"; return 1
  fi
  if x="$(transport_redirect)"; then
    AUTO_WHY="$x redirects the transport; an agent push goes over plain ssh or https only"; return 1
  fi
  key="$(url_key "$2")" || { AUTO_WHY="the push URL has no <host>/<path>"; return 1; }
  home="$(passwd_home)" || { AUTO_WHY="no home directory in the passwd entry"; return 1; }
  envf="$home/.config/bearing/bearing.env"
  line=""; [ -f "$envf" ] && line="$(grep -E '^BEARING_AUTO_PUSH[[:space:]]*=' "$envf" | tail -1)"
  v="${line#*=}"; v="${v%%#*}"; v="$(printf '%s' "$v" | tr -d "\"'" | tr ',' ' ')"
  set -f
  for x in $v; do   # an entry is <host>/<path>; a trailing / or .git and the host's case do not count
    x="${x%/}"; x="${x%.git}"
    x="$(printf '%s' "${x%%/*}" | tr 'A-Z' 'a-z')/${x#*/}"
    [ "$x" = "$key" ] && { ok=0; break; }
  done
  set +f
  [ "$ok" -eq 0 ] || AUTO_WHY="$key is not listed in BEARING_AUTO_PUSH"
  return "$ok"
}

# message_problem <message file> <task id or empty>: prints why the message
# breaks the rules and returns 1, or prints nothing and returns 0. commit-msg
# runs it on the message being written; pre-push runs it on every commit being
# pushed, so a commit made with --no-verify is still caught before it leaves.
message_problem() {
  local file="$1" task="$2" subject long
  subject="$(sed -n '1p' "$file")"
  [ -n "$subject" ] || { echo "empty commit message"; return 1; }
  case "$subject" in
    Merge\ *|Revert\ \"*|fixup!\ *|squash!\ *) return 0 ;;  # subjects git writes
  esac
  printf '%s' "$subject" | grep -Eq "$COMMIT_RE" \
    || { echo "subject must be Conventional, 'type(scope): summary', type one of ${COMMIT_TYPES//|/, }. Got: $subject"; return 1; }
  if [ -n "$task" ] && ! printf '%s' "$subject" | grep -qF "[$task]"; then
    echo "branch carries $task; the subject must end with [$task]. Got: $subject"; return 1
  fi
  if [ "$NO_AI_TRAILER" = 1 ] && grep -Eq "$AI_TRAILER_RE" "$file"; then
    echo "AI attribution trailer found; a commit names a person who answers for it"; return 1
  fi
  if [ "$NO_EM_DASH" = 1 ] && grep -qF "$EM_DASH" "$file"; then
    echo "em dash in the commit message; rewrite the sentence"; return 1
  fi
  if [ "$BODY_MAX" -gt 0 ]; then
    long="$(sed -n '3,$p' "$file" | grep -v '^#' | awk -v m="$BODY_MAX" 'length > m' | wc -l | tr -d ' ')"
    [ "$long" -eq 0 ] || { echo "$long body line(s) over $BODY_MAX characters; wrap the body"; return 1; }
  fi
  return 0
}

# Staged paths, NUL-separated so a path with spaces survives. Consume with
# `while IFS= read -r -d '' f` or `xargs -0`.
staged_files0() { git diff --cached --name-only -z --diff-filter=ACMR; }
