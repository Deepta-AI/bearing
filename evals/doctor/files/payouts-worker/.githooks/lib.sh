#!/usr/bin/env bash
# Shared helpers for the committed git hooks. Sourced by each hook.
set -u
hook_fail() { printf 'hook %s: %s\n' "${HOOK_NAME:-?}" "$*" >&2; exit 1; }
hook_note() { printf 'hook %s: %s\n' "${HOOK_NAME:-?}" "$*"; }
TASK_ID_RE='[A-Z][A-Z0-9]*-[0-9]+'
BRANCH_RE="^(feature|bugfix|chore|docs)/${TASK_ID_RE}-[A-Za-z0-9]+$"
COMMIT_RE="^(feat|fix|refactor|test|docs|chore|perf|build|ci)(\([a-z0-9._/-]+\))?!?: .{1,72}( \[${TASK_ID_RE}\])?$"
