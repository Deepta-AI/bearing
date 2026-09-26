#!/usr/bin/env bash
# install.sh: set up the Claude Code workflow on this machine.
#
#   bash install.sh [--profile minimal|standard|full] [--dry-run] [--no-claude]
#                   [--skip-gsd] [--skip-gstack] [--skip-superpowers] [--skip-packs]
#                   [--remote <git url>] [--uninstall]
#
# Idempotent. Steps, by profile:
#   minimal   the Bearing plugin from this checkout (or --remote), the user
#             env file ~/.config/bearing/bearing.env (from templates/user,
#             mode 600, never overwritten), the personal CLAUDE.md if absent,
#             then brg-doctor
#   standard  minimal plus Superpowers (official marketplace), gstack (GitHub)
#             and GSD Core (npx, non-interactive, --global --claude); the default
#   full      standard plus bin/brg-install-packs (the open-source skill packs
#             named as main choices per stage; see docs/THIRD_PARTY.md)
# --dry-run prints every action and touches nothing. --no-claude skips every
# claude CLI step and the plugin install: it only refreshes the kit checkout,
# writes the env file and prints the bin/brg-harness instruction for other
# coding harnesses. --uninstall removes the plugin and marketplace, asks
# before removing the env file, removes ~/.claude/CLAUDE.md only while it is
# still the untouched template, and prints how to unhook each repository.
# Prints a count of what it installed, what was already present, what it
# skipped and what failed; exits 1 when anything failed.
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"
profile=standard; dry=0; no_claude=0; uninstall=0
skip_gsd=0; skip_gstack=0; skip_sp=0; skip_packs=0; remote=""
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) profile="$2"; shift 2;;
    --dry-run) dry=1; shift;;
    --no-claude) no_claude=1; shift;;
    --uninstall) uninstall=1; shift;;
    --skip-gsd) skip_gsd=1; shift;;
    --skip-gstack) skip_gstack=1; shift;;
    --skip-superpowers) skip_sp=1; shift;;
    --skip-packs) skip_packs=1; shift;;
    --remote) remote="$2"; shift 2;;
    -h|--help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//'; exit 0;;
    *) echo "unknown option: $1" >&2; exit 2;;
  esac
done
case "$profile" in minimal|standard|full) ;; *) echo "--profile must be minimal, standard or full (got '$profile')" >&2; exit 2;; esac
installed=0; present=0; skipped=0; failed=0
did() { echo "installed  $*"; installed=$((installed+1)); }
had() { echo "present    $*"; present=$((present+1)); }
skip() { echo "skipped    $*"; skipped=$((skipped+1)); }
fail() { echo "FAILED     $*"; failed=$((failed+1)); }
# run CMD...: execute, or print under --dry-run (then succeed). runq is the
# same with the command's own output silenced.
run() { if [ "$dry" -eq 1 ]; then echo "would run  $*"; else "$@"; fi; }
runq() { if [ "$dry" -eq 1 ]; then echo "would run  $*"; else "$@" >/dev/null 2>&1; fi; }
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/bearing"
ENVF="$CONF_DIR/bearing.env"
mode_note=""; [ "$dry" -eq 0 ] || mode_note=" (dry run: nothing is changed)"

# marketplace_present <name>: the exact marketplace name from `claude plugin
# marketplace list` (a "❯ bearing" line, or a plain "bearing" first field),
# never a substring such as "smart".
marketplace_present() { claude plugin marketplace list 2>/dev/null | grep -Eq "^[[:space:]]*(❯[[:space:]]*)?$1[[:space:]]*\$"; }
plugin_present() { claude plugin list 2>/dev/null | grep -q "$1"; }

# ---------------------------------------------------------------- uninstall
if [ "$uninstall" -eq 1 ]; then
  echo "== uninstall$mode_note"
  removed=0; kept=0
  ask() { # prompt -> 0 on an explicit y
    local ans=""
    if [ "$dry" -eq 1 ]; then echo "would ask  $1"; return 0; fi
    [ -t 0 ] || [ -r /dev/tty ] || { echo "no terminal to confirm on; nothing removed" >&2; exit 1; }
    printf '%s [y/N] ' "$1"; read -r ans </dev/tty || true
    [ "$ans" = y ] || [ "$ans" = Y ]
  }
  ask "Remove the Bearing plugin and its marketplace from Claude Code?" || { echo "uninstall: cancelled, nothing removed"; exit 0; }
  if [ "$no_claude" -eq 1 ] || ! command -v claude >/dev/null; then skip "claude CLI steps (no claude)"; else
    if plugin_present 'bearing'; then runq claude plugin uninstall bearing@bearing && { echo "removed    plugin bearing@bearing"; removed=$((removed+1)); } || fail "claude plugin uninstall bearing@bearing"; else echo "absent     plugin bearing@bearing"; fi
    if marketplace_present bearing; then runq claude plugin marketplace remove bearing && { echo "removed    marketplace bearing"; removed=$((removed+1)); } || fail "claude plugin marketplace remove bearing"; else echo "absent     marketplace bearing"; fi
  fi
  if [ -f "$ENVF" ]; then
    if ask "Also delete $ENVF (holds your tracker credentials)?"; then run rm -f "$ENVF" && { echo "removed    $ENVF"; removed=$((removed+1)); }; else echo "kept       $ENVF"; kept=$((kept+1)); fi
  else echo "absent     $ENVF"; fi
  if [ -f "$HOME/.claude/CLAUDE.md" ]; then
    # Only a byte-identical copy is the untouched template; any edit keeps it.
    if cmp -s "$HOME/.claude/CLAUDE.md" "$KIT/templates/user/CLAUDE.md"; then
      run rm -f "$HOME/.claude/CLAUDE.md" && { echo "removed    ~/.claude/CLAUDE.md (still the untouched template)"; removed=$((removed+1)); }
    else echo "kept       ~/.claude/CLAUDE.md (edited by you)"; kept=$((kept+1)); fi
  else echo "absent     ~/.claude/CLAUDE.md"; fi
  echo "note: Superpowers, gstack, GSD Core and the skill packs are left in place; remove them with their own commands (docs/THIRD_PARTY.md)."
  echo "note: each adopted repository still points at its committed hooks; in each one run: git config --unset core.hooksPath"
  echo "install.sh --uninstall: $removed removed, $kept kept, $failed failed$mode_note"
  [ "$failed" -eq 0 ] || exit 1
  exit 0
fi

# ------------------------------------------------------------ prerequisites
echo "== prerequisites$mode_note (profile $profile)"
command -v git >/dev/null || { echo "missing: git. Install it first." >&2; exit 1; }
if [ "$no_claude" -eq 0 ]; then
  command -v claude >/dev/null || { echo "missing: claude. Install Claude Code first (https://code.claude.com/docs) or pass --no-claude." >&2; exit 1; }
fi
need_node=0; [ "$profile" = minimal ] || [ "$no_claude" -eq 1 ] || need_node=1
# A node from nvm, fnm or Volta is on PATH only after the shell's rc file
# loads the manager, and a non-interactive shell (an editor's terminal, a
# script) skips that. Look where the managers keep it before calling it
# missing: nvm's newest installed version, then fnm's and Volta's defaults.
node_dir() {
  local d nvm="${NVM_DIR:-$HOME/.nvm}/versions/node"
  if [ -d "$nvm" ]; then
    d="$(ls "$nvm" 2>/dev/null | sed -n 's/^v\([0-9]*\.[0-9]*\.[0-9]*\)$/\1/p' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)"
    [ -n "$d" ] && [ -x "$nvm/v$d/bin/node" ] && { echo "$nvm/v$d/bin"; return 0; }
  fi
  for d in "${FNM_DIR:-$HOME/.local/share/fnm}/aliases/default/bin" "$HOME/.fnm/aliases/default/bin" "${VOLTA_HOME:-$HOME/.volta}/bin"; do
    [ -x "$d/node" ] && { echo "$d"; return 0; }
  done
  return 1
}
if ! command -v node >/dev/null && d="$(node_dir)"; then
  PATH="$d:$PATH"; export PATH
  echo "node: not on PATH; using $d (the version manager's install)"
fi
for t in node npx; do
  if ! command -v "$t" >/dev/null; then
    if [ "$need_node" -eq 1 ]; then echo "missing: $t (node 22+); GSD Core and the skill packs need it. Install it or use --profile minimal." >&2; exit 1
    else echo "warning: $t not on PATH (not needed for this profile)"; fi
  fi
done
for t in jq make python3; do command -v "$t" >/dev/null || echo "warning: $t not on PATH; the kit's scripts and gates need it (brg-doctor will flag it)"; done
line="git $(git --version | awk '{print $3}')"
[ "$no_claude" -eq 1 ] || line="claude $(claude --version | head -1), $line"
! command -v node >/dev/null || line="$line, node $(node --version)"
echo "$line"

# ------------------------------------------------------------------ the kit
echo "== bearing"
if [ "$no_claude" -eq 1 ]; then
  if [ -d "$KIT/.git" ]; then
    rev="$(git -C "$KIT" rev-parse --short HEAD 2>/dev/null || echo '?')"
    if [ -n "$remote" ] || git -C "$KIT" remote get-url origin >/dev/null 2>&1; then
      if runq git -C "$KIT" pull --ff-only; then had "kit checkout $KIT (refreshed, was $rev)"; else had "kit checkout $KIT at $rev (pull skipped: no fast-forward or offline)"; fi
    else had "kit checkout $KIT at $rev (no remote to refresh from)"; fi
  else had "kit files at $KIT (not a git checkout; nothing to refresh)"; fi
  skip "claude plugin marketplace and plugin install (--no-claude)"
else
  if marketplace_present bearing; then had "marketplace bearing"; else
    if runq claude plugin marketplace add "${remote:-$KIT}"; then did "marketplace bearing (${remote:-$KIT})"; else fail "claude plugin marketplace add ${remote:-$KIT}"; fi; fi
  if plugin_present 'bearing'; then
    runq claude plugin update bearing@bearing || true; had "plugin Bearing (updated)"; else
    if runq claude plugin install bearing@bearing; then did "plugin bearing"; else fail "claude plugin install bearing@bearing"; fi; fi
fi

# ------------------------------------------------------- third-party packs
if [ "$profile" = minimal ] || [ "$no_claude" -eq 1 ]; then
  echo "== third-party packs"; skip "superpowers, gstack, GSD Core ($([ "$no_claude" -eq 1 ] && echo '--no-claude' || echo 'profile minimal'))"
else
  echo "== third-party packs"
  if [ "$skip_sp" -eq 1 ]; then skip "superpowers"; elif plugin_present 'superpowers'; then had "superpowers"; else
    if runq claude plugin install superpowers@claude-plugins-official; then did "superpowers"; else fail "claude plugin install superpowers@claude-plugins-official"; fi; fi

  if [ "$skip_gstack" -eq 1 ]; then skip "gstack"; else
    gdir="$HOME/.claude/skills/gstack"
    if [ -d "$gdir/.git" ]; then
      if ! runq git -C "$gdir" pull --ff-only; then fail "gstack: update failed (git pull --ff-only in $gdir; see git -C $gdir status)"
      elif ! runq bash -c "cd '$gdir' && ./setup"; then fail "gstack: update failed (./setup in $gdir exited non-zero)"
      else had "gstack (updated to $(cat "$gdir/VERSION" 2>/dev/null || echo '?'))"; fi
    else
      if ! runq git clone --single-branch --depth 1 https://github.com/garrytan/gstack.git "$gdir"; then fail "gstack: clone failed (https://github.com/garrytan/gstack.git)"
      elif ! runq bash -c "cd '$gdir' && ./setup"; then fail "gstack: setup failed (./setup in $gdir exited non-zero)"
      else did "gstack $(cat "$gdir/VERSION" 2>/dev/null || echo '')"; fi
    fi
  fi

  if [ "$skip_gsd" -eq 1 ]; then skip "GSD Core"; else
    if ls "$HOME/.claude/skills" 2>/dev/null | grep -qi '^gsd' || plugin_present 'gsd'; then had "GSD Core"; else
      # GSD Core wants node 24+; it prints an engine warning on older nodes but installs.
      if runq npx --yes @opengsd/gsd-core@latest --global --claude; then did "GSD Core (global, Claude Code)"; else skip "GSD Core (installer failed; rerun: npx @opengsd/gsd-core@latest --global --claude)"; fi
    fi
  fi
fi

echo "== open-source skill packs (main choices per stage; see docs/THIRD_PARTY.md)"
if [ "$profile" != full ]; then skip "skill packs (profile $profile; --profile full or bin/brg-install-packs)"
elif [ "$no_claude" -eq 1 ]; then skip "skill packs (--no-claude)"
elif [ "$skip_packs" -eq 1 ]; then skip "skill packs"
elif [ "$dry" -eq 1 ]; then echo "would run  bash $KIT/bin/brg-install-packs"
elif bash "$KIT/bin/brg-install-packs"; then did "skill packs (bin/brg-install-packs)"
else fail "skill packs: rerun bin/brg-install-packs after fixing the cause"; fi

# ------------------------------------------------------- user configuration
echo "== user configuration"
if [ -f "$ENVF" ]; then had "$ENVF"
else
  if [ "$dry" -eq 1 ]; then echo "would copy $KIT/templates/user/bearing.env -> $ENVF (mode 600)"; did "$ENVF"
  else mkdir -p "$CONF_DIR"; ( umask 077; cp "$KIT/templates/user/bearing.env" "$ENVF" ); did "$ENVF (set BEARING_TRACKER and the rest; none is a valid tracker)"; fi
fi
# Record the profile so doctor knows which packs this machine should have.
if [ "$dry" -eq 1 ]; then echo "would set BEARING_PROFILE=$profile in $ENVF"
elif [ -f "$ENVF" ]; then
  tmpf="$ENVF.tmp.$$"
  ( umask 077
    if grep -q '^BEARING_PROFILE=' "$ENVF"; then
      awk -v p="$profile" '/^BEARING_PROFILE=/{print "BEARING_PROFILE=" p; next} {print}' "$ENVF" > "$tmpf"
    else
      { cat "$ENVF"; printf 'BEARING_PROFILE=%s\n' "$profile"; } > "$tmpf"
    fi ) && mv "$tmpf" "$ENVF" && echo "ok         BEARING_PROFILE=$profile recorded in $ENVF"
fi

echo "== personal CLAUDE.md"
if [ "$no_claude" -eq 1 ]; then skip "~/.claude/CLAUDE.md (--no-claude)"
elif [ -f "$HOME/.claude/CLAUDE.md" ]; then had "~/.claude/CLAUDE.md"; else
  if [ "$dry" -eq 1 ]; then echo "would copy $KIT/templates/user/CLAUDE.md -> ~/.claude/CLAUDE.md"; did "~/.claude/CLAUDE.md"
  else mkdir -p "$HOME/.claude"; cp "$KIT/templates/user/CLAUDE.md" "$HOME/.claude/CLAUDE.md"; did "~/.claude/CLAUDE.md (edit the first line)"; fi
fi

echo "== doctor"
if [ "$no_claude" -eq 1 ]; then skip "brg-doctor (checks the Claude Code install; --no-claude)"
elif [ "$dry" -eq 1 ]; then echo "would run  bash $KIT/bin/brg-doctor"
else bash "$KIT/bin/brg-doctor" || true; fi

echo "install.sh: $installed installed, $present already present, $skipped skipped, $failed failed$mode_note"
if [ "$no_claude" -eq 1 ]; then
  echo "next: in each repository run  bash $KIT/bin/brg-harness <cursor|codex|gemini|copilot|opencode|windsurf|cline|zed|kiro|all> --dir <repo>"
else echo "Restart Claude Code to load new plugins."; fi
[ "$failed" -eq 0 ] || exit 1
