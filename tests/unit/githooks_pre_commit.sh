#!/usr/bin/env bash
# tests/unit/githooks_pre_commit.sh: templates/repo/.githooks/pre-commit on
# empty input. Run by hand or by `git commit` with nothing staged it fails
# with "0 staged files, nothing checked". It passes, naming the reason, on a
# deletion-only commit, on `git commit --allow-empty`, and on a merge whose
# tree equals HEAD. A staged file is checked and counted. Each case runs in a
# fresh throwaway repository with the hooks installed. Empty sandbox
# placeholders (.mcp.json, .bashrc) are refused; a real .mcp.json passes.
set -u
. "$(dirname "$0")/../lib/assert.sh"
HOOKS="$KIT/templates/repo/.githooks"

# repo: a fresh repository with the hooks installed and one commit on main.
repo() {
  local d
  d="$(tmpdir)"
  (
    cd "$d" || exit 1
    git init -q -b main . && git config user.email t@example.com && git config user.name t
    git config commit.gpgsign false
    cp -R "$HOOKS" .githooks && bash .githooks/install.sh >/dev/null
    printf 'a\n' > a.txt && git add a.txt .githooks && git commit -qm 'chore: init' >/dev/null 2>&1
  ) || return 1
  printf '%s' "$d"
}
# at <dir> <cmd...>: run the command inside the repository.
at() { local d="$1"; shift; (cd "$d" && "$@"); }

t_begin "nothing staged: the hook run by hand fails with the count"
d="$(repo)"
assert_exit 1 at "$d" .githooks/pre-commit
assert_contains "$T_OUT" "0 staged files, nothing checked"
t_end

t_begin "nothing staged: git commit is refused by the hook"
d="$(repo)"
assert_exit 1 at "$d" git commit -m 'chore: nothing'
assert_contains "$T_OUT" "0 staged files, nothing checked"
t_end

t_begin "git commit --allow-empty passes and says why"
d="$(repo)"
assert_exit 0 at "$d" git commit --allow-empty -m 'chore: empty'
assert_contains "$T_OUT" "empty commit requested with --allow-empty"
t_end

t_begin "a deletion-only commit passes and counts the deletions"
d="$(repo)"
at "$d" git rm -q a.txt
assert_exit 0 at "$d" git commit -m 'chore: remove a'
assert_contains "$T_OUT" "0 files to scan, 1 deletion(s) staged"
t_end

t_begin "a merge whose tree equals HEAD passes"
d="$(repo)"
at "$d" git checkout -q -b other
printf 'b\n' > "$d/b.txt"; at "$d" git add b.txt; at "$d" git commit -qm 'chore: b' >/dev/null 2>&1
at "$d" git checkout -q main
at "$d" git merge -q -s ours --no-commit other >/dev/null 2>&1
assert_exit 0 at "$d" git commit -m 'chore: merge other'
assert_contains "$T_OUT" "merge commit whose tree equals HEAD"
t_end

t_begin "a staged file is checked and counted"
d="$(repo)"
printf 'c\n' > "$d/c.txt"; at "$d" git add c.txt
assert_exit 0 at "$d" .githooks/pre-commit
assert_contains "$T_OUT" "1 staged file(s) checked"
t_end

t_begin "empty sandbox placeholders are refused; the real files are not"
d="$(repo)"
: > "$d/.mcp.json"; : > "$d/.bashrc"; at "$d" git add .mcp.json .bashrc
assert_exit 1 at "$d" .githooks/pre-commit
assert_contains "$T_OUT" "sandbox placeholder file(s) staged: .bashrc .mcp.json"
assert_contains "$T_OUT" "git restore --staged .bashrc .mcp.json"
at "$d" git restore --staged .mcp.json .bashrc; rm -f "$d/.mcp.json" "$d/.bashrc"
printf '{"mcpServers":{}}\n' > "$d/.mcp.json"; mkdir -p "$d/.vscode"; printf '{}\n' > "$d/.vscode/settings.json"
at "$d" git add .mcp.json .vscode/settings.json
assert_exit 0 at "$d" .githooks/pre-commit
assert_contains "$T_OUT" "2 staged file(s) checked"
t_end

t_begin "placeholders are refused in a subdirectory too, where a command ran"
d="$(repo)"
mkdir -p "$d/web/.claude"; : > "$d/web/.mcp.json"; : > "$d/web/.claude/hooks"; : > "$d/web/.claude/launch.json"
at "$d" git add web
assert_exit 1 at "$d" .githooks/pre-commit
assert_contains "$T_OUT" "sandbox placeholder file(s) staged: web/.claude/hooks web/.claude/launch.json web/.mcp.json"
d="$(repo)"
mkdir -p "$d/web/.claude"; printf '{"mcpServers":{}}\n' > "$d/web/.mcp.json"; printf '{}\n' > "$d/web/.claude/launch.json"
at "$d" git add web
assert_exit 0 at "$d" .githooks/pre-commit
assert_contains "$T_OUT" "2 staged file(s) checked"
t_end

t_summary
