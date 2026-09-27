#!/usr/bin/env bash
# Point git at the committed hooks. Idempotent. Run once per clone, or let
# `make setup` do it.
set -eu
root="$(git rev-parse --show-toplevel)"
git -C "$root" config core.hooksPath .githooks
chmod +x "$root"/.githooks/commit-msg "$root"/.githooks/pre-commit "$root"/.githooks/pre-push
echo "git hooks installed: core.hooksPath=.githooks"
