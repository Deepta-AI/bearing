#!/usr/bin/env bash
# Shared helpers for the committed git hooks. Sourced by each hook.
set -u

hook_fail() { printf 'hook %s: %s\n' "${HOOK_NAME:-?}" "$*" >&2; exit 1; }
hook_note() { printf 'hook %s: %s\n' "${HOOK_NAME:-?}" "$*"; }

# Task id: an upper-case prefix, then one or more dash-number groups, in
# whatever shape the configured tracker uses: PREFIX-123, PREFIX-00-017.
TASK_ID_RE='[A-Z][A-Z0-9]*(-[0-9]+)+'
# feature/PREFIX-123-PascalName, release/v1.2.3
BRANCH_RE="^(feature|bugfix|hotfix|chore|docs|release)/(${TASK_ID_RE}-[A-Za-z0-9]+|v[0-9]+\.[0-9]+\.[0-9]+)$"
COMMIT_RE="^(feat|fix|refactor|test|docs|chore|perf|build|ci|revert)(\([a-z0-9._/-]+\))?!?: .{1,72}( \[${TASK_ID_RE}\])?$"

# Trailers no commit may carry.
AI_TRAILER_RE='^(Co-Authored-By|Co-authored-by): .*(Claude|Anthropic|Copilot|ChatGPT|Gemini|Cursor|Devin)|^(Generated with|🤖 Generated)'

# Staged paths, NUL-separated so a path with spaces survives. Consume with
# `while IFS= read -r -d '' f` or `xargs -0`.
staged_files0() { git diff --cached --name-only -z --diff-filter=ACMR; }
