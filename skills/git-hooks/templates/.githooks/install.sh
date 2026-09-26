#!/usr/bin/env bash
# Point git at the committed hooks. Idempotent. Run once per clone, or let
# `make setup` do it.
set -eu
root="$(git rev-parse --show-toplevel)"
# Write only when the value differs: Claude Code's sandbox mounts .git/config
# read-only, and an unconditional write failed make setup there.
if [ "$(git -C "$root" config --get core.hooksPath || true)" != ".githooks" ]; then
  git -C "$root" config core.hooksPath .githooks 2>/dev/null || {
    echo "could not set core.hooksPath=.githooks (.git/config is not writable); run: git config core.hooksPath .githooks" >&2; exit 1; }
fi
chmod +x "$root"/.githooks/commit-msg "$root"/.githooks/pre-commit "$root"/.githooks/pre-push
n=0
for h in commit-msg pre-commit pre-push; do [ -f "$root/.githooks/$h" ] && n=$((n+1)); done
[ "$n" -eq 3 ] || { echo "expected 3 hooks, found $n" >&2; exit 1; }
echo "git hooks installed: core.hooksPath=.githooks ($n hooks)"
