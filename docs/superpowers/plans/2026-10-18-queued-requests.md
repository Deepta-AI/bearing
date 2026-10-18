# Queued Requests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three queued requests: an opt-in push of the current feature branch after the gate (default off), a light flow for marketing sites and landing pages, and explicit multi-repo task sets, with the smallest change to the existing skills.

**Architecture:** One new script, `plugins/bearing/bin/brg-push`, decides and performs the only push Bearing makes; skills may `check` and `request`, and only `brg-guard stop-gate` (a hook, outside the sandbox) may `run` it. The raw `git push` stays blocked by the guard, the settings deny and the sandbox. The site flow is data in `docs/flows.json`, chosen per repository by a project config key. Task sets are a `## Repos` section in each repository's committed progress file, read by a new `progress.py set`, with the rules in one new shared reference, `plugins/bearing/references/task-set.md`.

**Tech Stack:** bash 3.2 (macOS CI), GNU and BSD portable (`make lint-portable`), Python 3 stdlib, jq where the hooks already use it, Make. Tests use `tests/lib/assert.sh`.

**Spec:** `docs/superpowers/specs/2026-10-18-queued-requests-design.md`

**Base:** rebase `feat/QueuedRequests` onto `main` after sub-projects 2, 3 and 4 merge, then run this plan. Line numbers below are at `e6d407d`; find each anchor by its text after the rebase.

## Global Constraints

- No em dashes in any file (`make lint-prose`).
- No company or client names, no private tracker ids (`make lint-neutral`).
- Every new gate, check or subcommand that judges something fails on empty input and prints the count it checked.
- A skill that asks uses AskUserQuestion in `allowed-tools` and cites `${CLAUDE_PLUGIN_ROOT}/references/console.md`.
- bash 3.2 portable: no `sed -i`, `grep -P`, `readlink -f`, `date -d`, `perl`, no `${var,,}`, no associative arrays, no `mapfile`. Python 3 stdlib only.
- Every SKILL.md at 200 lines or fewer; detail goes to `references/`.
- Every command a skill body runs is granted in its `allowed-tools` (`make lint-tools`); never a `Bash(git -C` or `Bash(bash:*)` grant.
- New files under `plugins/bearing`: exactly 2 (`bin/brg-push`, `references/task-set.md`). `make lint-plugin-size` prints `bearing` at its post-rebase count plus 2.
- `brg-push` runs `git push` in one form only: `git push --no-follow-tags --set-upstream origin HEAD:refs/heads/<branch>`, with `GIT_TERMINAL_PROMPT=0`. No force, no tags, no other remote, no other refspec, anywhere.
- `BEARING_AUTO_PUSH` is read from the `bearing.env` file only (path `${BEARING_ENV:-${XDG_CONFIG_HOME:-$HOME/.config}/bearing/bearing.env}`), never from an environment variable of that name.
- Hook steps added here exit 0 on their own failure and log `<gate> not-run <reason>`; only the existing Stop gate may exit 2.
- State writes are atomic: `<file>.tmp`, then `mv`.
- Commits: Conventional Commits, no attribution trailer of any kind. Bearing never pushes this branch.
- After touching a skill, `docs/flows.json` or `bin/gen-guide.py`: `make docs` and commit what it regenerates; never hand-edit `docs/SKILLS.md`, `site/src/data/handbook.json`, `devguide/src/data/internals.json`, `plugins/bearing/bin/flow-steps.tsv`.
- The repository gate: `make check` ends with `check: passed`.

## Review Focus

1. The agent must have no path to a push it can trigger alone: `brg-push run` from Bash is denied by the guard, `bearing.env` cannot be written by `brg-config`, Edit, or the sandbox, and a `bearing.env` changed during the session is refused. Pinned in Tasks 1, 3 and 5.
2. A stale request must never fire: a request for another sha, or a request left after a refusal, pushes nothing. Pinned in Task 3.
3. Repositories with hooks from before this change: the pre-push hook refuses the agent push, and `brg-push check` says so before the request (condition `pre-push`). Pinned in Tasks 2 and 4.
4. A single-repository task must look exactly as before: no `## Repos` section, no `Set:` line, the definition-of-done item `n/a`. Pinned in Tasks 8 and 9.
5. A `bugfix/` branch in a site repository still follows the bugfix flow. Pinned in Task 10.

---

## File Structure

| File | Responsibility |
|---|---|
| `plugins/bearing/bin/brg-push` (create) | `check`, `request`, `run`, `status`, `optin-record` |
| `plugins/bearing/references/task-set.md` (create) | The task-set rules the five skills cite |
| `plugins/bearing/bin/brg-guard` (modify) | verb row `brg-push|run`; `stop-gate` runs a requested push on `passed`; `session` records the opt-in and prints the push result once; `task-id` prints it once |
| `plugins/bearing/bin/brg-config` (modify) | refuses to set the auto-push key |
| `plugins/bearing/bin/brg-session` (modify) | `next-step` reads the project `flow` key |
| `plugins/bearing/bin/brg-autopilot` (modify) | `g_mr` accepts a push by `brg-push`; stage and report text |
| `plugins/bearing/templates/repo/.githooks/{lib.sh,pre-push}` and `plugins/bearing/skills/git-hooks/templates/.githooks/{lib.sh,pre-push}` (modify) | `auto_push_allowed`; the agent push rules |
| `plugins/bearing/templates/repo/.claude/settings.json` (modify) | deny `Edit(~/.config/bearing/**)` and `Bash(bash *bin/brg-push run*)`; `_readme` |
| `plugins/bearing/templates/repo/AGENTS.md` (modify) | rule 2 names the exception |
| `plugins/bearing/templates/user/bearing.env` (modify) | the commented key |
| `plugins/bearing/hooks/hooks.json` (modify) | description |
| `plugins/bearing/skills/session-handoff/scripts/progress.py`, `templates/progress.md` (modify) | `--repo`, `## Repos`, `set` |
| `plugins/bearing/skills/{merge-request,autopilot,start-task,session-handoff,definition-of-done,workflow}/SKILL.md` (modify) | push request, task set, site flow |
| `plugins/bearing/skills/autopilot/references/review-smoke-and-mr.md` (modify) | push request, task set |
| `docs/flows.json` (modify) | the `site` flow; the `mr` step wording |
| `bin/gen-guide.py`, `README.md`, `CONTRIBUTING.md`, `docs/INSTALL.md`, `docs/WORKFLOW.md` (hand-written lines), `devguide/src/pages/{Architecture,Autopilot,Start,Home}.tsx`, `site/src/pages/{Guides,Home}.tsx`, `site/src/lib/nav.ts` (modify) | claims and flow counts |
| `tests/unit/push_check.sh`, `push_run.sh`, `githooks_pre_push.sh`, `push_claims.sh`, `task_set_skills.sh` (create) | named in each task |
| `tests/unit/{config_helper,guard_deny_table,autopilot_state,progress,session_resume}.sh` (modify) | named in each task |
| `evals/{merge-request,start-task,workflow}/evals.json` (modify) | one case each |
| `CHANGELOG.md` (modify) | `[Unreleased]` |

---

### Task 0: Confirm a Stop hook can push while the sandbox is on

The design (spec A3, A4) rests on hooks running outside the sandbox with the engineer's credentials. Prove it before building on it.

**Files:**
- Create (throwaway, not committed): `.scratch/push-hook-probe/`

- [ ] **Step 1: Write a probe repository with the template sandbox and a Stop hook**

```bash
mkdir -p .scratch/push-hook-probe && cd .scratch/push-hook-probe
git init -q -b main && git commit -q --allow-empty -m init
git init -q --bare ../probe-remote.git && git remote add origin "$PWD/../probe-remote.git"
git switch -q -c feature/T-1-Probe && git commit -q --allow-empty -m "chore: probe"
mkdir -p .claude
jq '.hooks = {"Stop": [{"hooks": [{"type": "command", "command": "git push --no-follow-tags origin HEAD:refs/heads/feature/T-1-Probe > \"$CLAUDE_PROJECT_DIR/probe.log\" 2>&1; echo rc=$? >> \"$CLAUDE_PROJECT_DIR/probe.log\"", "timeout": 15}]}]}' \
  ../../plugins/bearing/templates/repo/.claude/settings.json > .claude/settings.json
```

- [ ] **Step 2: Run one headless turn**

Run: `claude -p "Say hello." --permission-mode acceptEdits; cat probe.log; git -C ../probe-remote.git branch`
Expected: `rc=0` in `probe.log` and `feature/T-1-Probe` listed in the bare remote. Then repeat with a real remote over SSH on a scratch repository you own (`git remote set-url origin <ssh url>`): `rc=0` again, proving the hook has the network and credentials the sandbox denies to Bash.

- [ ] **Step 3: Record the result**

If both pushes succeed: proceed as written. If the hook push fails under the sandbox: stop and tell the user; the fallback (spec Q3 territory) is `brg-push run` from the launcher only (`brg-autopilot launch`) and from a printed command for interactive sessions, and Tasks 3 and 6 change accordingly. Delete `.scratch/push-hook-probe/` and `.scratch/probe-remote.git` either way. No commit.

---

### Task 1: `brg-config` refuses the auto-push key; the key documented

**Files:**
- Modify: `plugins/bearing/bin/brg-config` (after the key validation, before the user branch, about line 38)
- Modify: `plugins/bearing/templates/user/bearing.env` (append a block after `BEARING_NONINTERACTIVE`)
- Modify: `docs/INSTALL.md` (the key table in "3. Configure")
- Test: `tests/unit/config_helper.sh`

**Interfaces:**
- Produces: `brg-config set <key mapping to BEARING_AUTO_PUSH> ...` exits 2 with stderr `brg-config: BEARING_AUTO_PUSH is set by hand in bearing.env, never by a tool`; `get` still works.

- [ ] **Step 1: Write the failing test** (append to `tests/unit/config_helper.sh` before `t_summary`)

```bash
t_begin "set refuses the auto-push key in every spelling"
printf 'BEARING_TRACKER=none\n' > "$envf"
for k in auto-push auto_push AUTO.PUSH Auto-Push; do
  assert_exit 2 run set "$k" "Shop/Server/ShopApi" --user
  assert_contains "$T_OUT" "BEARING_AUTO_PUSH is set by hand"
  assert_exit 2 run set "$k" on
done
assert_eq "BEARING_TRACKER=none" "$(cat "$envf")" "bearing.env unchanged"
t_end

t_begin "get reads the auto-push key"
printf 'BEARING_AUTO_PUSH="Shop/Server/ShopApi, Shop/Client/ShopWeb"\n' > "$envf"
assert_exit 0 run get auto-push --user
assert_eq "Shop/Server/ShopApi, Shop/Client/ShopWeb" "$T_OUT"
t_end
```

- [ ] **Step 2: Run it to see it fail**

Run: `bash tests/unit/config_helper.sh`
Expected: FAIL on `set refuses the auto-push key in every spelling` (exit 0, file changed).

- [ ] **Step 3: Implement**

In `brg-config`, after the `case "$val"` newline check:

```bash
if [ "$op" = set ] && [ "BEARING_$(printf '%s' "$key" | tr 'a-z.-' 'A-Z__')" = BEARING_AUTO_PUSH ]; then
  echo "brg-config: BEARING_AUTO_PUSH is set by hand in bearing.env, never by a tool" >&2; exit 2
fi
```

Add to the header comment: "set refuses the auto-push key (exit 2): the engineer writes it by hand." Append to `templates/user/bearing.env`:

```
# Optional: the repositories where Bearing may push the current feature
# branch for you, after make check passed and only when merge-request or
# autopilot asked for it. Default: none, Bearing never pushes. Each entry is
# the repository's path as its origin url spells it, without the host and
# .git (group/sub/repo), separated by spaces or commas. Never main, master,
# develop or release branches, never a tag, never a force push, never a
# merge. Read from this file only; set it here by hand (brg-config refuses
# it), before the session that uses it starts.
# BEARING_AUTO_PUSH="Shop/Server/ShopApi Shop/Client/ShopWeb"
```

In `docs/INSTALL.md`, after the `BEARING_ORG_ID` row: `| \`BEARING_AUTO_PUSH\` | repositories (origin path without host and \`.git\`) where merge-request and autopilot may have the current feature branch pushed after the gate; read from this file only | empty (Bearing never pushes) |`.

- [ ] **Step 4: Run the test**

Run: `bash tests/unit/config_helper.sh && make lint-prose`
Expected: `config_helper.sh: <n> cases, <m> assertions, 0 failed`; `lint-prose: <N> files, 0 em dashes`.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-config plugins/bearing/templates/user/bearing.env docs/INSTALL.md tests/unit/config_helper.sh
git commit -m "feat(config): document BEARING_AUTO_PUSH and refuse to set it from a tool"
```

---

### Task 2: `brg-push check` and `optin-record`

**Files:**
- Create: `plugins/bearing/bin/brg-push` (mode 755)
- Test: `tests/unit/push_check.sh` (create, mode 755)

**Interfaces:**
- Produces: `brg-push check` prints one line per condition, `ok <name>: <detail>` or `no <name>: <detail>`, for the nine conditions `opt-in origin branch not-protected clean ahead gate fast-forward pre-push` in that order, then `push-check: 9 conditions, <M> met`; exit 0 when 9 met, 1 otherwise, 2 outside a git repository with stderr `brg-push: not a git repository; 0 conditions checked`.
- Produces: `brg-push optin-record` writes `.bearing/state/.push-optin` holding `on` or `off` (atomic) and prints nothing; exit 0 always.
- Produces (used by Task 3, 4): shell functions `repo_path` (origin url to `group/name`: scheme, user, host, port and `.git` removed; a local path loses its leading `/`) and `optin_listed` (reads `BEARING_AUTO_PUSH` from the file, quotes stripped, commas as spaces).

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/push_check.sh: brg-push check prints one line per condition and
# the count, refuses outside a repository, and names each unmet condition;
# optin-record writes on or off from bearing.env, read from the file only.
# bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
P="$KIT/plugins/bearing/bin/brg-push"
cfg="$(tmpdir)"; export XDG_CONFIG_HOME="$cfg"; unset BEARING_ENV BEARING_AUTO_PUSH
mkdir -p "$cfg/bearing"; envf="$cfg/bearing/bearing.env"

setup() { # a repository on feature/ABC-1-Thing, one commit ahead of origin/main, check passed
  repo="$(tmpdir)"; remote="$(tmpdir)/remote.git"
  git init -q --bare "$remote"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$repo/Makefile"
  git -C "$repo" add Makefile; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" remote add origin "$remote"; git -C "$repo" push -q origin main 2>/dev/null
  git -C "$repo" switch -q -c feature/ABC-1-Thing
  printf 'x\n' > "$repo/a.txt"; git -C "$repo" add a.txt; git -C "$repo" commit -q -m "feat: a [ABC-1]"
  mkdir -p "$repo/.bearing/state"; sleep 1; touch "$repo/.bearing/state/.check-passed"
  path="${remote%.git}"; path="${path#/}"
  printf 'BEARING_AUTO_PUSH="%s"\n' "$path" > "$envf"
  ( cd "$repo" && bash "$P" optin-record )
}
in_repo() { ( cd "$repo" && bash "$P" "$@" ) }

t_begin "outside a git repository: exit 2 and 0 conditions"
d="$(tmpdir)"
assert_exit 2 bash -c "cd '$d' && bash '$P' check"
assert_contains "$T_OUT" "0 conditions checked"
t_end

t_begin "everything met: nine ok lines and the count"
setup
assert_exit 0 in_repo check
assert_contains "$T_OUT" "ok opt-in:"
assert_contains "$T_OUT" "ok gate: 1 file(s) compared"
assert_contains "$T_OUT" "push-check: 9 conditions, 9 met"
t_end

t_begin "not listed in bearing.env"
setup; printf 'BEARING_AUTO_PUSH="other/repo"\n' > "$envf"; ( cd "$repo" && bash "$P" optin-record )
assert_exit 1 in_repo check
assert_contains "$T_OUT" "no opt-in:"
t_end

t_begin "an environment variable does not opt in"
setup; : > "$envf"; ( cd "$repo" && BEARING_AUTO_PUSH="$path" bash "$P" optin-record )
assert_exit 1 in_repo check
assert_contains "$T_OUT" "no opt-in:"
t_end

t_begin "protected and release branches"
setup
git -C "$repo" switch -q main
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no branch:"; assert_contains "$T_OUT" "no not-protected:"
git -C "$repo" switch -q -c release/v1.2.0
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no not-protected:"
t_end

t_begin "detached HEAD"
setup; git -C "$repo" switch -q --detach
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no branch: detached"
t_end

t_begin "dirty tree"
setup; printf 'y\n' >> "$repo/a.txt"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no clean:"
t_end

t_begin "stale gate"
setup; sleep 1; printf 'z\n' > "$repo/a.txt"; git -C "$repo" commit -q -am "fix: z [ABC-1]"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no gate: 1 of 1 file(s) newer than the last make check"
t_end

t_begin "zero commits ahead"
setup; git -C "$repo" switch -q -c feature/ABC-2-Empty main
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no ahead: 0 commits"
t_end

t_begin "not a fast-forward of origin's branch"
setup
other="$(tmpdir)"; git clone -q "$remote" "$other"; git -C "$other" switch -q -c feature/ABC-1-Thing
git -C "$other" -c user.email=o@example.com -c user.name=o commit -q --allow-empty -m "chore: other"
git -C "$other" push -q origin feature/ABC-1-Thing 2>/dev/null; git -C "$repo" fetch -q origin
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no fast-forward:"
t_end

t_begin "hooks path without auto push support"
setup; mkdir -p "$repo/.githooks"; printf 'PUSH_CONFIRM=tty\n' > "$repo/.githooks/lib.sh"; git -C "$repo" config core.hooksPath .githooks
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no pre-push: .githooks/lib.sh has no auto_push_allowed"
t_end

t_summary
```

- [ ] **Step 2: Run it to see it fail**

Run: `chmod +x tests/unit/push_check.sh && bash tests/unit/push_check.sh`
Expected: FAIL on every case (`brg-push` does not exist).

- [ ] **Step 3: Implement `brg-push` (check and optin-record)**

Header comment: what it is, the five subcommands with their exit codes, "the only git push Bearing runs", "run is for the Stop hook; the guard refuses it from Bash", bash 3.2. Body outline:

```bash
#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
sub="${1:-}"; [ $# -gt 0 ] && shift
root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "brg-push: not a git repository; 0 conditions checked" >&2; exit 2; }
st="$root/.bearing/state"
envf="${BEARING_ENV:-${XDG_CONFIG_HOME:-$HOME/.config}/bearing/bearing.env}"

repo_path() {
  local u; u="$(git -C "$root" remote get-url origin 2>/dev/null)" || return 1
  u="${u%.git}"
  case "$u" in *://*) u="${u#*://}"; u="${u#*/}";; /*) ;; *:*) u="${u#*:}";; esac
  printf '%s\n' "${u#/}"
}
optin_listed() { # the file only; never the environment
  local line v p x
  [ -f "$envf" ] || return 1
  line="$(grep -E '^BEARING_AUTO_PUSH[[:space:]]*=' "$envf" | tail -1)"; [ -n "$line" ] || return 1
  v="${line#*=}"; v="${v%%#*}"; v="$(printf '%s' "$v" | tr -d "\"'" | tr ',' ' ')"
  p="$(repo_path)" || return 1
  for x in $v; do [ "$x" = "$p" ] && return 0; done
  return 1
}
n=0; met=0
cond() { n=$((n+1)); if [ "$2" -eq 0 ]; then met=$((met+1)); echo "ok $1: $3"; else echo "no $1: $3"; fi; }
base_ref() { local b; for b in origin/develop origin/main origin/master; do git -C "$root" rev-parse -q --verify "$b" >/dev/null && { echo "$b"; return 0; }; done; return 1; }
```

`conditions` (a function used by `check` and, in Task 3, by `run`) evaluates, in order:
`opt-in` (`check`: `$st/.push-optin` reads `on`; `run`: `optin_listed`), `origin` (`repo_path` succeeds; detail the path), `branch` (`git symbolic-ref -q --short HEAD`; detached prints `detached`; must match `^(feature|bugfix|hotfix|chore|docs)/[A-Z][A-Z0-9]*(-[0-9]+)+-[A-Za-z0-9]+$` with `grep -Eq`), `not-protected` (not `main|master|develop|release/*`, and not a word of `PROTECTED_BRANCHES` read with `sed -n "s/^PROTECTED_BRANCHES='\(.*\)'.*/\1/p"` from the hooks path's `lib.sh` when present), `clean` (`git status --porcelain --untracked-files=no` empty; detail the count), `ahead` (`git rev-list --count <base>..HEAD` at least 1; no base is `no ahead: no origin/develop, origin/main or origin/master`), `gate` (files: `git diff --name-only <base>...HEAD` plus `bash "$here/brg-changed" --root "$root"`, sorted unique, existing only; zero files is `no gate: 0 files on the branch`; no marker is `no gate: make check has never passed`; else count those `-nt` the marker: zero is `ok gate: <k> file(s) compared`, otherwise `no gate: <j> of <k> file(s) newer than the last make check`), `fast-forward` (no `refs/remotes/origin/<branch>`, or `git merge-base --is-ancestor origin/<branch> HEAD`), `pre-push` (`git config --get core.hooksPath` empty, or `<that dir>/lib.sh` contains `auto_push_allowed()`; else `no pre-push: <dir>/lib.sh has no auto_push_allowed (update the hooks from the template)`).

`check)`: run `conditions check`, print `push-check: $n conditions, $met met`, exit 0 when equal, else 1.
`optin-record)`: `mkdir -p "$st"`; `if optin_listed; then v=on; else v=off; fi`; write `$st/.push-optin.tmp`, `mv`; `exit 0`.
Unknown or empty subcommand: usage on stderr, exit 2.

- [ ] **Step 4: Run the tests and the lints**

Run: `bash tests/unit/push_check.sh && make lint-shell lint-portable lint-plugin-size`
Expected: `push_check.sh: 11 cases, <m> assertions, 0 failed`; `lint-shell: <n> scripts` (one more than before); `lint-portable` clean; `lint-plugin-size:` shows `bearing <count+1> files`.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-push tests/unit/push_check.sh
git commit -m "feat(push): brg-push check names each condition for an opt-in feature branch push"
```

---

### Task 3: `request`, `run`, `status`; the guard row; the Stop gate runs it

**Files:**
- Modify: `plugins/bearing/bin/brg-push`
- Modify: `plugins/bearing/bin/brg-guard` (verb rows near line 69; `stop-gate` `passed` at line 1672; `session` after the session mark near line 1574; `task-id` near line 1550; header comment line 64)
- Test: `tests/unit/push_run.sh` (create), `tests/unit/guard_deny_table.sh`

**Interfaces:**
- Consumes: `conditions`, `optin_listed`, `repo_path` (Task 2).
- Produces: `brg-push request` exits 1 with the check output when a condition is unmet; else writes `.bearing/state/push-request` (`branch=<b>`, `sha=<HEAD>`, `time=<UTC>`) and prints `push: requested <branch> <short sha>`.
- Produces: `brg-push run --id <sid> [--foreground]` adds conditions `request` and `opt-in-age` (11 total) and prints `push-run: 11 conditions, <M> met`; on any unmet, deletes the request, writes `push-result` `push refused: <first unmet>`, logs `push refused`, exits 1. All met without `--foreground`: starts `nohup bash "$0" run --id <sid> --foreground >> "$st/push.log" 2>&1 &`, prints `bearing push: started for <branch>`, exits 0. With `--foreground`: deletes the request, pushes, writes `push-result` `pushed <branch> <sha> to origin <UTC time>` or `push failed: <last stderr line>`, logs `push pushed|failed`.
- Produces: `brg-push status` prints the `push-result` line or `push: none`; with `--unseen` prints it only when `.bearing/state/.push-result-seen` is older, then touches that file.
- Produces: `brg-guard command 'brg-push run ...'` exits 2 with `Bearing blocked 'brg-push run (the Stop hook runs it)'`.
- Produces: `brg-guard stop-gate` on `passed` with a request present and `brg-push` beside it prints the `run` line; `brg-guard session` runs `optin-record` and prints `status --unseen`; `brg-guard task-id` prints `status --unseen`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/push_run.sh`: reuse `setup` and `in_repo` from Task 2 (copy them; tests do not source each other), plus a session mark:

```bash
mark() { touch "$repo/.bearing/state/.session-s1"; }

t_begin "request needs every condition"
setup; git -C "$repo" switch -q main
assert_exit 1 in_repo request
assert_eq 0 "$([ -f "$repo/.bearing/state/push-request" ] && echo 1 || echo 0)" "no request written on main"
t_end

t_begin "request then run --foreground pushes the branch and nothing else"
setup; git -C "$repo" tag v9.9.9; sleep 1; mark
assert_exit 0 in_repo request
assert_contains "$T_OUT" "push: requested feature/ABC-1-Thing"
assert_exit 0 in_repo run --id s1 --foreground
assert_contains "$(git -C "$remote" branch)" "feature/ABC-1-Thing"
assert_eq "" "$(git -C "$remote" tag)" "no tag reached the remote"
assert_contains "$(cat "$repo/.bearing/state/push-result")" "pushed feature/ABC-1-Thing $(git -C "$repo" rev-parse HEAD) to origin"
assert_eq 0 "$([ -f "$repo/.bearing/state/push-request" ] && echo 1 || echo 0)" "request consumed"
assert_contains "$(cat "$repo/.bearing/state/gates.log" 2>/dev/null)" "	push	pushed	"
t_end

t_begin "run refuses a request for another sha"
setup; sleep 1; mark; in_repo request >/dev/null
git -C "$repo" commit -q --allow-empty -m "chore: later [ABC-1]"; touch "$repo/.bearing/state/.check-passed"
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no request:"
assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed"
assert_eq 0 "$([ -f "$repo/.bearing/state/push-request" ] && echo 1 || echo 0)" "refused request deleted"
t_end

t_begin "run refuses an opt-in written during the session"
setup; mark; sleep 1; printf 'BEARING_AUTO_PUSH="%s"\n' "$path" > "$envf"; in_repo request >/dev/null
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no opt-in-age:"
t_end

t_begin "run without a request pushes nothing"
setup; sleep 1; mark
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "push-run: 11 conditions"
assert_contains "$T_OUT" "no request: none"
t_end

t_begin "status prints the result once with --unseen"
setup; sleep 1; mark; in_repo request >/dev/null; in_repo run --id s1 --foreground >/dev/null
assert_exit 0 in_repo status --unseen; assert_contains "$T_OUT" "pushed feature/ABC-1-Thing"
assert_exit 0 in_repo status --unseen; assert_eq "" "$T_OUT"
assert_exit 0 in_repo status; assert_contains "$T_OUT" "pushed feature/ABC-1-Thing"
t_end

t_begin "the stop gate runs a requested push when it passes"
setup; sleep 1; mark; in_repo request >/dev/null
assert_exit 0 bash -c "cd '$repo' && bash '$GUARD' stop-gate --id s1"
assert_contains "$T_OUT" "bearing push: started for feature/ABC-1-Thing"
for i in 1 2 3 4 5 6 7 8 9 10; do [ -f "$repo/.bearing/state/push-result" ] && break; sleep 1; done
assert_contains "$(cat "$repo/.bearing/state/push-result")" "pushed feature/ABC-1-Thing"
t_end

t_begin "a blocked stop gate never pushes"
setup; sleep 1; mark; in_repo request >/dev/null; sleep 1; printf 'dirty\n' > "$repo/b.txt"
assert_exit 2 bash -c "cd '$repo' && bash '$GUARD' stop-gate --id s1"
sleep 2; assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed"
t_end

t_summary
```

In `tests/unit/guard_deny_table.sh`, before the `verb table and version` case:

```bash
t_begin "brg-push run is the Stop hook's, never the agent's"
assert_exit 2 bash "$GUARD" command 'bash "/x/plugins/bearing/bin/brg-push" run --id s'
assert_contains "$T_OUT" "blocked 'brg-push run (the Stop hook runs it)'"
assert_exit 2 bash "$GUARD" command '/x/bin/brg-push run'
assert_exit 0 bash "$GUARD" command 'bash "/x/plugins/bearing/bin/brg-push" check'
assert_exit 0 bash "$GUARD" command 'bash "/x/plugins/bearing/bin/brg-push" request'
assert_exit 0 bash "$GUARD" command 'bash "/x/plugins/bearing/bin/brg-push" status'
t_end
```

- [ ] **Step 2: Run them to see them fail**

Run: `chmod +x tests/unit/push_run.sh && bash tests/unit/push_run.sh; bash tests/unit/guard_deny_table.sh`
Expected: FAIL on every `push_run.sh` case (unknown subcommands) and on `brg-push run is the Stop hook's` (exit 0).

- [ ] **Step 3: Implement**

`brg-push`:
- `request)`: `conditions check`; unmet: print the lines and `push-check: ...`, exit 1. Met: write the three `key=value` lines atomically to `$st/push-request`, print `push: requested <branch> <short sha>`.
- `run)`: parse `--id` and `--foreground`. `conditions run` (opt-in from `optin_listed`), then `request` (file present, `branch=` equals the current branch, `sha=` equals HEAD; absent prints `no request: none`) and `opt-in-age` (session mark `$st/.session-<id>` exists and `bearing.env` is not `-nt` it). Print `push-run: $n conditions, $met met`. Unmet: `rm -f "$st/push-request"`, `result "push refused: <first unmet>"`, `log_gate push refused`, exit 1. Met, not foreground: the `nohup` line, exit 0. Foreground: `rm -f` the request; when the remote branch exists, `git fetch -q origin <branch>` then re-test fast-forward; `GIT_TERMINAL_PROMPT=0 git -C "$root" push --no-follow-tags --set-upstream origin "HEAD:refs/heads/$branch" >>"$st/push.log" 2>&1`; result line and `log_gate push pushed|failed`.
- `result` writes `$st/push-result` atomically. `log_gate` appends the `gates.log` line in the guard's format (`time<TAB>gate<TAB>outcome<TAB>ms<TAB>label`).
- `status)`: as in Interfaces.

`brg-guard`:
- After the `git|push` row: `brg-push|run|brg-push run (the Stop hook runs it)`. Line 64 comment: append "The one exception: brg-push run, which only the Stop hook calls, under the engineer's BEARING_AUTO_PUSH opt-in."
- `stop-gate`, replace `[ "$fresh" -gt 0 ] || { gate_log stop-gate passed; exit 0; }` with:

```bash
    if [ "$fresh" -eq 0 ]; then
      gate_log stop-gate passed
      if [ -f "$state/push-request" ] && [ -f "$(dirname "$0")/brg-push" ]; then
        bash "$(dirname "$0")/brg-push" run --id "$sid" 2>&1 | tail -1
      fi
      exit 0
    fi
```

- `session`: after the session mark block, `[ -f "$(dirname "$0")/brg-push" ] && { bash "$(dirname "$0")/brg-push" optin-record >/dev/null 2>&1; bash "$(dirname "$0")/brg-push" status --unseen 2>/dev/null; }`.
- `task-id`: before the task lookup, the same `status --unseen` line (prints nothing when seen).
- `README.md:94`: the verb count line becomes the new `--verbs` count (`bash plugins/bearing/bin/brg-guard --verbs | wc -l`, and the program count).

- [ ] **Step 4: Run the tests**

Run: `bash tests/unit/push_run.sh && bash tests/unit/push_check.sh && bash tests/unit/guard_deny_table.sh && bash tests/unit/guard_session_stop.sh && bash tests/unit/guard_latency.sh`
Expected: each ends `0 failed`; `push_run.sh: 8 cases`.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-push plugins/bearing/bin/brg-guard README.md tests/unit/push_run.sh tests/unit/guard_deny_table.sh
git commit -m "feat(push): the Stop hook runs a requested push after the gate passes; the agent cannot"
```

---

### Task 4: The pre-push hook accepts an opted-in agent push of a feature branch only

**Files:**
- Modify: `plugins/bearing/templates/repo/.githooks/lib.sh`, `plugins/bearing/templates/repo/.githooks/pre-push`
- Modify (copy, identical): `plugins/bearing/skills/git-hooks/templates/.githooks/lib.sh`, `.../pre-push`
- Test: `tests/unit/githooks_pre_push.sh` (create)

**Interfaces:**
- Produces: `lib.sh` function `auto_push_allowed` (exit 0 when the engineer's `bearing.env` file lists this repository's origin path; same parsing as `brg-push`).
- Produces: in `pre-push`, with an agent variable set and `auto_push_allowed`: a tag ref fails `hook_fail "an agent push carries only branches: <ref>"`; a protected or `release/*` ref fails as today; a non-fast-forward fails `hook_fail "an agent push is never forced: <branch>"`; otherwise `hook_note "agent push allowed by BEARING_AUTO_PUSH: <n> branch ref(s)"` and the gate runs as today.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/githooks_pre_push.sh: the committed pre-push hook refuses an agent
# push without the opt-in, allows a fast-forward feature branch with it, and
# refuses a tag, a protected branch and a forced update with it. bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="$KIT/plugins/bearing/templates/repo/.githooks"
cfg="$(tmpdir)"; mkdir -p "$cfg/bearing"; envf="$cfg/bearing/bearing.env"; unset BEARING_ENV
setup() {
  repo="$(tmpdir)"; remote="$(tmpdir)/r.git"; git init -q --bare "$remote"
  git -C "$repo" init -q -b main; cp -R "$H" "$repo/.githooks"
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  printf 'check:\n\t@echo check: passed\n' > "$repo/Makefile"; git -C "$repo" add -A; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" remote add origin "$remote"; git -C "$repo" push -q origin main 2>/dev/null
  git -C "$repo" config core.hooksPath .githooks
  git -C "$repo" switch -q -c feature/ABC-1-Thing; git -C "$repo" commit -q --allow-empty -m "feat: a [ABC-1]"
  p="${remote%.git}"; printf 'BEARING_AUTO_PUSH="%s"\n' "${p#/}" > "$envf"
}
agent_push() { ( cd "$repo" && CLAUDECODE=1 XDG_CONFIG_HOME="$cfg" git push "$@" 2>&1 ) }

t_begin "agent push refused without the opt-in"
setup; : > "$envf"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing"
t_end

t_begin "agent push of a feature branch allowed with the opt-in, gate run"
setup
t_run agent_push --no-follow-tags origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "agent push allowed by BEARING_AUTO_PUSH: 1 branch ref(s)"
assert_contains "$T_OUT" "gate passed"
t_end

t_begin "a tag is refused even with the opt-in"
setup; git -C "$repo" tag v1.0.0
t_run agent_push origin v1.0.0
assert_contains "$T_OUT" "an agent push carries only branches"
t_end

t_begin "a protected branch is refused with the opt-in"
setup
t_run agent_push origin HEAD:refs/heads/main
assert_contains "$T_OUT" "direct push to main is not allowed"
t_end

t_begin "a forced update is refused with the opt-in"
setup; agent_push origin HEAD:refs/heads/feature/ABC-1-Thing >/dev/null
git -C "$repo" commit -q --amend -m "feat: b [ABC-1]"
t_run agent_push --force origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "an agent push is never forced"
t_end

t_begin "the two copies of the hooks are identical"
assert_exit 0 diff -rq "$H" "$KIT/plugins/bearing/skills/git-hooks/templates/.githooks"
t_end

t_summary
```

- [ ] **Step 2: Run it to see it fail**

Run: `chmod +x tests/unit/githooks_pre_push.sh && bash tests/unit/githooks_pre_push.sh`
Expected: FAIL on the four opt-in cases; the first case and the copies case pass.

- [ ] **Step 3: Implement**

`lib.sh`, after `is_protected`: `auto_push_allowed` (the `repo_path` and `optin_listed` logic from Task 2, reading `${BEARING_ENV:-${XDG_CONFIG_HOME:-$HOME/.config}/bearing/bearing.env}`; a comment says it reads the file only). `pre-push`: move the agent detection (`for v in CLAUDECODE ...`, lines 62-65) above the ref loop and set `auto=0; [ -n "$agent" ] && auto_push_allowed && auto=1`. In the loop, when `auto=1`: a non-`refs/heads/*` remote ref calls `hook_fail "an agent push carries only branches: $remote_ref"` instead of the note; a `release/*` branch fails like a protected one; a non-zero `remote_sha` that is not an ancestor of `local_sha` (`git merge-base --is-ancestor`) fails with the forced message. In the `PUSH_CONFIRM` case, every branch that refuses an agent first checks `[ "$auto" -eq 1 ]` and then notes the allow line instead of failing. Copy both files to `plugins/bearing/skills/git-hooks/templates/.githooks/`. Update the comment at `pre-push:60-61`: "The engineer pushes; a coding agent does not, except under the engineer's BEARING_AUTO_PUSH opt-in, a fast-forward of a feature branch."

- [ ] **Step 4: Run the tests**

Run: `bash tests/unit/githooks_pre_push.sh && bash tests/unit/githooks_install.sh && bash tests/unit/githooks_pre_commit.sh && make lint-skills`
Expected: each ends `0 failed`; `lint-skills: <n> skills ...` (the templates diff is clean).

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/templates/repo/.githooks plugins/bearing/skills/git-hooks/templates/.githooks tests/unit/githooks_pre_push.sh
git commit -m "feat(githooks): pre-push lets an opted-in agent push a feature branch, never a tag or a forced update"
```

---

### Task 5: Settings deny, AGENTS.md rule 2, hooks description

**Files:**
- Modify: `plugins/bearing/templates/repo/.claude/settings.json` (`_readme` lines 10 and 16; `permissions.deny`)
- Modify: `plugins/bearing/templates/repo/AGENTS.md:16-17`
- Modify: `plugins/bearing/hooks/hooks.json:2`
- Test: `tests/unit/push_check.sh` (one case)

**Interfaces:**
- Produces: `permissions.deny` holds `Edit(~/.config/bearing/**)` and `Bash(bash *bin/brg-push run*)`.

- [ ] **Step 1: Write the failing test** (append to `tests/unit/push_check.sh` before `t_summary`)

```bash
t_begin "the settings template denies edits to the user config and the run verb"
S="$KIT/plugins/bearing/templates/repo/.claude/settings.json"
deny="$(jq -r '.permissions.deny[]' "$S")"
assert_contains "$deny" "Edit(~/.config/bearing/**)"
assert_contains "$deny" "Bash(bash *bin/brg-push run*)"
assert_contains "$deny" "Bash(git push:*)"
assert_contains "$(cat "$KIT/plugins/bearing/templates/repo/AGENTS.md")" "BEARING_AUTO_PUSH"
t_end
```

- [ ] **Step 2: Run it to see it fail**

Run: `bash tests/unit/push_check.sh`
Expected: FAIL on `the settings template denies edits ...`.

- [ ] **Step 3: Implement**

Add the two deny entries next to `Bash(git push:*)`. `_readme` line 10 becomes "local commits (reversible; push, amend and rebase stay blocked; the one push is brg-push run from the Stop hook, under the engineer's BEARING_AUTO_PUSH)"; line 16 becomes "The engineer pushes, opens Merge Requests and deploys; the agent prepares, and may request a feature branch push where the engineer opted the repository in.". AGENTS.md rule 2:

```
2. Never push, open a merge or pull request, merge, tag or deploy. Prepare the
   command and hand it to the engineer. Where the engineer opted this
   repository in (BEARING_AUTO_PUSH), `merge-request` may request a push of
   the feature branch; the Stop hook makes it after the gate.
```

`hooks.json` description: "Bearing hooks. Fast, file-scoped, and each prints what it did. The engineer pushes and deploys; the agent does not, except a feature branch push the Stop hook makes where the engineer opted the repository in."

- [ ] **Step 4: Run the tests and the budgets**

Run: `bash tests/unit/push_check.sh && make lint-json lint-budget validate`
Expected: `0 failed`; `lint-json: <n> files parsed`; `lint-budget: ... AGENTS.md <bytes under 3600>`; `validate: ... passed (strict)`.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/templates/repo/.claude/settings.json plugins/bearing/templates/repo/AGENTS.md plugins/bearing/hooks/hooks.json tests/unit/push_check.sh
git commit -m "feat(templates): deny edits to the user config; rule 2 names the opt-in push"
```

---

### Task 6: merge-request and autopilot request the push; the autopilot gate accepts it

**Files:**
- Modify: `plugins/bearing/skills/merge-request/SKILL.md` (lines 3, 5, 10, 93-98, 123, 128)
- Modify: `plugins/bearing/skills/autopilot/SKILL.md` (lines 3, 13-15, 74-81, 93), `references/review-smoke-and-mr.md:28`
- Modify: `plugins/bearing/bin/brg-autopilot` (lines 9, 112, `g_mr` 796-815, 959)
- Test: `tests/unit/autopilot_state.sh`

**Interfaces:**
- Consumes: `brg-push check|request|status` (Tasks 2, 3); `.bearing/state/push-result` line `pushed <branch> <sha> to origin <time>`.
- Produces: `g_mr` passes when the upstream sha equals HEAD and `push-result` records that sha; note `; upstream <ref> pushed by brg-push at <short sha>`.

- [ ] **Step 1: Write the failing test** (in `tests/unit/autopilot_state.sh`, after the `the mr gate refuses a branch that has an upstream` case, reusing its setup shape)

```bash
t_begin "the mr gate accepts an upstream brg-push pushed at HEAD, and nothing else"
d8="$(tmpdir)/run8"; d_save="$d"; d="$d8"
git init -q -b main "$d"; printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$d/Makefile"; commit init
bare="$(tmpdir)/remote8.git"; git init -q --bare "$bare"; git -C "$d" remote add origin "$bare"
git -C "$d" checkout -q -b feature/T-8-x
# (same autopilot.json writer as the case above, mr pending)
mkdir -p "$d/.scratch" "$d/docs/autopilot"; printf 'mr\n' > "$d/.scratch/mr-T-8.md"; printf 'r\n' > "$d/docs/autopilot/r.md"; git -C "$d" add docs; commit report
git -C "$d" push -q -u origin feature/T-8-x 2>/dev/null
printf 'pushed feature/T-8-x %s to origin 2026-10-18T10:00:00Z\n' "$(git -C "$d" rev-parse HEAD)" > "$d/.bearing/state/push-result"
assert_exit 0 ap "done" mr
assert_contains "$T_OUT" "pushed by brg-push"
printf 'pushed feature/T-8-x %s to origin 2026-10-18T10:00:00Z\n' "0000000000000000000000000000000000000000" > "$d/.bearing/state/push-result"
assert_exit 1 ap "done" mr
assert_contains "$T_OUT" "the run must not push"
d="$d_save"
t_end
```

- [ ] **Step 2: Run it to see it fail**

Run: `bash tests/unit/autopilot_state.sh`
Expected: FAIL on the new case (exit 1, "the run must not push").

- [ ] **Step 3: Implement**

`brg-autopilot`:
- `def pushed_by_brg_push(d)`: read `.bearing/state/push-result`; match `^pushed (\S+) ([0-9a-f]{40}) to origin`; return the sha or `""`.
- In `g_mr`, before the two refusals: `if upstream and upstream_sha(d) == git(d, "rev-parse", "HEAD") == pushed_by_brg_push(d): note = f"; upstream {upstream} pushed by brg-push at {sha[:8]}"` and skip them.
- Line 9 docstring: "Nothing here pushes, merges or deploys; a push, where the engineer opted the repository in, is brg-push's from the Stop hook."; line 112 gate text: "nothing pushed except by brg-push under the opt-in"; line 959: "changes it. Nothing was merged or deployed; the push is the engineer's, or brg-push's where the repository is opted in."

`merge-request/SKILL.md`:
- description: `'Prepares the merge request for the current branch: gate run, commit audit, diff summary, description, ticket link; pushes only where opted in. Use when asked to "prepare the MR", "write the PR description".'` (at most 220 characters; `make lint-skills` checks).
- line 10: "The engineer pushes and opens the MR in under a minute with what this produces, or, where they opted the repository in, the Stop hook pushes the branch for them."
- step 8, after the description is printed: "Then `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-push" check`. Exit 0: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-push" request` and print `Push: requested; the Stop hook pushes <branch> to origin when this turn ends and the gate holds (brg-push status shows the result)`. Otherwise print its first `no` line and the push command as below."
- output contract line 123: `Push: requested (opt-in) | yours: git push -u origin <branch>   MR | PR: <url pattern>`.
- gotcha line 128: "Never run `git push`, ... If asked, decline in one line and print the command. The only push path is `brg-push request` after a passing `brg-push check`; the Stop hook makes the push, never this skill."
- `allowed-tools` add `Bash(bash *bin/brg-push check*), Bash(bash *bin/brg-push request*), Bash(bash *bin/brg-push status*)`.

`autopilot/SKILL.md`:
- description: `'Runs unattended from one requirement statement to a prepared merge request, taking each decision as Proposed for review; pushes only where opted in. Use when asked to "autopilot this", "run it end to end" or "build this unattended".'`
- lines 13-15: "The run never merges or deploys, and pushes only through `brg-push` where the engineer opted the repository in: the guard, the sandbox and the pre-push hook stop any other push, and the last stage prints the push command when there is no opt-in."
- step 10: replace "Do not run it." with "Then `brg-push check`; exit 0: `brg-push request` (the run's last Stop pushes); else print the command for the engineer."
- output contract: `Push: requested (opt-in) | yours: git push -u origin <branch>`.
- `references/review-smoke-and-mr.md:28`: same rule, one sentence. `allowed-tools` is a bare `Bash` already.

- [ ] **Step 4: Run the tests and lints**

Run: `bash tests/unit/autopilot_state.sh && make lint-skills lint-tools lint-skill-size`
Expected: `0 failed`; `lint-skills: ...` no problems; `lint-tools:` 0 ungranted; `lint-skill-size:` largest unchanged or under 200.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/skills/merge-request plugins/bearing/skills/autopilot plugins/bearing/bin/brg-autopilot tests/unit/autopilot_state.sh
git commit -m "feat(merge-request): request the opt-in push after the check; autopilot's mr gate accepts it"
```

---

### Task 7: Every "never pushes" claim names the exception

**Files:**
- Modify: `README.md` (lines 6, 85, 120, 237-243), `CONTRIBUTING.md:120`, `bin/gen-guide.py:800`, `docs/flows.json` (the two `mr` steps, lines 503-510 and 887-894), `docs/WORKFLOW.md:232,243`, `plugins/bearing/skills/start-task/SKILL.md:100,161`, `devguide/src/pages/Architecture.tsx:49-53,207`, `devguide/src/pages/Autopilot.tsx:165`, `devguide/src/pages/Start.tsx:133`, `devguide/src/pages/Home.tsx:28`, `site/src/pages/Guides.tsx:167,443`
- Test: `tests/unit/push_claims.sh` (create)

**Interfaces:**
- Produces: a test that, for each file in the spec A8 table marked "qualifier", fails when a line says the agent or a skill "never pushes" (or "the engineer pushes") without `BEARING_AUTO_PUSH`, `opt` (opt-in, opted) or `brg-push` within the same or next line; prints `push-claims: <n> files, <k> claims, 0 unqualified`; fails on zero files.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/push_claims.sh: every public "never pushes" claim names the
# opt-in exception (spec A8). Counts files and claims; fails on zero.
set -u
. "$(dirname "$0")/../lib/assert.sh"
files="README.md CONTRIBUTING.md bin/gen-guide.py docs/flows.json docs/WORKFLOW.md
plugins/bearing/templates/repo/AGENTS.md plugins/bearing/hooks/hooks.json
plugins/bearing/skills/merge-request/SKILL.md plugins/bearing/skills/autopilot/SKILL.md
plugins/bearing/skills/start-task/SKILL.md
devguide/src/pages/Architecture.tsx devguide/src/pages/Autopilot.tsx devguide/src/pages/Start.tsx
devguide/src/pages/Home.tsx site/src/pages/Guides.tsx"
t_begin "every never-pushes claim is qualified"
out="$(cd "$KIT" && python3 - $files <<'PY'
import re, sys
claim = re.compile(r"never push(es)?\b|engineer pushes|agent never pushes", re.I)
ok = re.compile(r"BEARING_AUTO_PUSH|\bopt(s|ed)?\b|brg-push", re.I)
n = k = bad = 0
for f in sys.argv[1:]:
    n += 1
    lines = open(f, encoding="utf-8").read().split("\n")
    for i, l in enumerate(lines):
        if claim.search(l):
            k += 1
            if not ok.search(l + " " + (lines[i + 1] if i + 1 < len(lines) else "")):
                bad += 1; print(f"unqualified: {f}:{i + 1}")
if n == 0 or k == 0:
    print(f"push-claims: {n} files, {k} claims, nothing checked"); sys.exit(1)
print(f"push-claims: {n} files, {k} claims, {bad} unqualified"); sys.exit(1 if bad else 0)
PY
)"
assert_contains "$out" " 0 unqualified"
t_end
t_summary
```

- [ ] **Step 2: Run it to see it fail**

Run: `chmod +x tests/unit/push_claims.sh && bash tests/unit/push_claims.sh`
Expected: FAIL, with `unqualified:` lines for `README.md:6`, `CONTRIBUTING.md:120`, `docs/flows.json:509`, `docs/flows.json:893`, `docs/WORKFLOW.md:243`, and the devguide and site pages.

- [ ] **Step 3: Rewrite each claim as the spec A8 table says**

Keep each sentence short and true for a repository without the opt-in. Examples: `README.md:6` "(the agent never pushes unless you opt a repository in, and then only its feature branch after the gate; every gate prints a count; everything traces)"; `docs/flows.json` bugfix `mr` "why": "It prepares everything and pushes only where you opted the repository in."; feature `mr` "does": "The gate, the commit audit and the filled template; you push, or the Stop hook does where you opted the repository in."; `bin/gen-guide.py:800` "description in .scratch, push command; the engineer pushes, or the Stop hook where the repository opts in"; `Architecture.tsx` WALLS `says` for `guard` and `deny` add "brg-push run is the one exception, and only the Stop hook calls it", `prepush` adds "unless the engineer's BEARING_AUTO_PUSH lists the repository and the push is a feature branch fast-forward"; the `207` paragraph adds one sentence on the opt-in. `start-task:100` "which the engineer runs, or which merge-request requests where the engineer opted the repository in"; `:161` keeps the command and adds "(or merge-request requests it under the opt-in)". `README.md:85` Stop row adds the push; `:120` adds "The one exception is opt-in: list a repository in `BEARING_AUTO_PUSH` and merge-request can ask the Stop hook to push its feature branch after the gate (`brg-push`)."; `:237-243` names the key. Then `make docs`.

- [ ] **Step 4: Run the test and the generated-docs check**

Run: `bash tests/unit/push_claims.sh && make docs && make lint-docs lint-prose`
Expected: `push_claims.sh: 1 cases, 1 assertions, 0 failed`; `lint-docs: 5 generated docs up to date`.

- [ ] **Step 5: Commit**

```bash
git add README.md CONTRIBUTING.md bin/gen-guide.py docs plugins/bearing/skills/start-task devguide site tests/unit/push_claims.sh
git commit -m "docs: every never-pushes claim names the opt-in feature branch push"
```

---

### Task 8: `progress.py` gains the `## Repos` section and `set`

**Files:**
- Modify: `plugins/bearing/skills/session-handoff/scripts/progress.py` (docstring, `LISTS`, `render`, the argument parser, `check`, new `cmd_set`)
- Modify: `plugins/bearing/skills/session-handoff/templates/progress.md` (one guidance comment line under Links naming the optional section)
- Test: `tests/unit/progress.sh`

**Interfaces:**
- Produces: `write --repo "<n>. <Name> (<path>)"` (repeatable; replaces; `none` clears); the file gets `## Repos` after `## Links` only when the list is non-empty.
- Produces: `check` reports `repos: order numbers must be 1..N, each once` and `repos: item "<item>" is not "<n>. <Name> (<path>)"`; more than 8 items: `repos: at most 8 repositories in a set`.
- Produces: `set [--root DIR] --task ID` prints one row per repository, `<n>. <Name> <path>: <ready | merged | not ready: <reason>>`, then `set: N repos, R ready, M merged, K not ready; merge order A, B, C`; exit 1 on no progress file, zero repositories or a missing path; 0 otherwise.

- [ ] **Step 1: Write the failing tests** (append to `tests/unit/progress.sh` before `t_summary`)

```bash
t_begin "write --repo adds the Repos section; without it there is none"
d="$(repo ABC-30-Set)"
assert_exit 0 python3 "$P" write --root "$d" --task ABC-30 --title Set --criteria 1 --next "start"
assert_not_contains "$(cat "$d/docs/progress/ABC-30.md")" "## Repos"
assert_exit 0 python3 "$P" write --root "$d" --task ABC-30 --repo "1. ShopApi (../ShopApi)" --repo "2. ShopWeb (.)"
body="$(cat "$d/docs/progress/ABC-30.md")"
assert_contains "$body" "## Repos"
assert_contains "$body" "- 1. ShopApi (../ShopApi)"
assert_exit 0 python3 "$P" check --root "$d"
t_end

t_begin "check rejects a duplicate order number"
assert_exit 0 python3 "$P" write --root "$d" --task ABC-30 --repo "1. ShopApi (../ShopApi)" --repo "1. ShopWeb (.)"
assert_exit 1 python3 "$P" check --root "$d"
assert_contains "$T_OUT" "repos: order numbers must be 1..N, each once"
t_end

t_begin "set reads every repository and counts"
parent="$(tmpdir)"; api="$parent/ShopApi"; web="$parent/ShopWeb"
for r in "$api" "$web"; do
  git -C "$parent" init -q -b develop "$(basename "$r")"
  git -C "$r" config user.name t; git -C "$r" config user.email t@example.com
  git -C "$r" commit -q --allow-empty -m init; git -C "$r" switch -q -c feature/ABC-31-Set
done
printf 'x\n' > "$api/a.go"; git -C "$api" add a.go; git -C "$api" commit -q -m "feat: a [ABC-31]"
mkdir -p "$api/.bearing/state"; sleep 1; touch "$api/.bearing/state/.check-passed"
python3 "$P" write --root "$web" --task ABC-31 --title Set --criteria 1 --next s --repo "1. ShopApi (../ShopApi)" --repo "2. ShopWeb (.)" >/dev/null
assert_exit 0 python3 "$P" set --root "$web" --task ABC-31
assert_contains "$T_OUT" "1. ShopApi ../ShopApi: ready"
assert_contains "$T_OUT" "2. ShopWeb .: not ready: make check has never passed"
assert_contains "$T_OUT" "set: 2 repos, 1 ready, 0 merged, 1 not ready; merge order ShopApi, ShopWeb"
t_end

t_begin "set fails on zero repositories and on a missing path"
assert_exit 1 python3 "$P" set --root "$d" --task ABC-99
assert_contains "$T_OUT" "no docs/progress/ABC-99.md"
python3 "$P" write --root "$web" --task ABC-31 --repo "1. Gone (../Gone)" --repo "2. ShopWeb (.)" >/dev/null
assert_exit 1 python3 "$P" set --root "$web" --task ABC-31
assert_contains "$T_OUT" "1. Gone ../Gone: missing"
python3 "$P" write --root "$web" --task ABC-31 --repo none >/dev/null
assert_exit 1 python3 "$P" set --root "$web" --task ABC-31
assert_contains "$T_OUT" "set: 0 repos, nothing checked"
t_end
```

- [ ] **Step 2: Run them to see them fail**

Run: `bash tests/unit/progress.sh`
Expected: FAIL on the four new cases (`--repo` unknown, `set` unknown).

- [ ] **Step 3: Implement**

`LISTS` gains `("repos", "Repos")`; `render` writes `## Repos` and its items after the Links block only when `rec.get("repos")`; the parser adds `--repo` (append, like `--done`). `check` validates with `REPO_RE = re.compile(r"^(\d+)\. ([A-Za-z0-9._-]+) \((.+)\)$")`, numbers equal to `range(1, N+1)`, `N <= 8`. `cmd_set`: read this repository's file (`docs/progress/<ID>.md`), parse items; for each, `p = os.path.normpath(os.path.join(root, path))`; missing when not a directory with `.git`; else run `git --no-optional-locks -C p ...` through the existing `git()` helper extended with `--no-optional-locks` for this use: branch present (`rev-parse -q --verify refs/heads/<this repository's branch name>`); its own progress Status (read `p/docs/progress/<ID>.md` when present) `merged` gives `merged`; uncommitted (`status --porcelain --untracked-files=no`) gives `not ready: <n> uncommitted`; the gate rule from spec A3 condition 7 (base `origin/develop`, `origin/main`, `develop`, `main`, the first that resolves; files from `diff --name-only <base>...<branch>` plus the porcelain list; marker `.bearing/state/.check-passed`), reasons `make check has never passed`, `<j> of <k> file(s) newer than the last make check`, `0 files on the branch`; else `ready`. The docstring gains `set` and `--repo`.

- [ ] **Step 4: Run the tests**

Run: `bash tests/unit/progress.sh && make lint-templates`
Expected: `progress.sh: <n> cases, <m> assertions, 0 failed`; `lint-templates:` passes.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/skills/session-handoff/scripts/progress.py plugins/bearing/skills/session-handoff/templates/progress.md tests/unit/progress.sh
git commit -m "feat(progress): a Repos section and a set report for tasks that span repositories"
```

---

### Task 9: The task-set reference and the five skills

**Files:**
- Create: `plugins/bearing/references/task-set.md`
- Modify: `plugins/bearing/skills/start-task/SKILL.md` (argument-hint, Inputs, step 7, output contract)
- Modify: `plugins/bearing/skills/session-handoff/SKILL.md` (step 6 handoff block)
- Modify: `plugins/bearing/skills/definition-of-done/SKILL.md` (the item list, after sub-project 3's last item; `allowed-tools`)
- Modify: `plugins/bearing/skills/merge-request/SKILL.md` (step 6, output contract)
- Modify: `plugins/bearing/skills/autopilot/SKILL.md` (step 10), `references/review-smoke-and-mr.md`
- Test: `tests/unit/task_set_skills.sh` (create)

**Interfaces:**
- Consumes: `progress.py write --repo`, `progress.py set` (Task 8).
- Produces: `start-task <ID> [Name] --repos <Name,Name,...>`; output contract line `Set: <n> repos, merge order <A, B, C>; run in each sibling: start-task <ID> <Name> --repos <list>`.
- Produces: merge-request output contract line `Set: <k> of <n>; merge after: <Name> | first` (only with a `## Repos` section).
- Produces: definition-of-done item "task set" (`n/a` without a `## Repos` section).

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/task_set_skills.sh: the five skills cite the task-set reference,
# and each stays at 200 lines or fewer. Counts the skills; fails on zero.
set -u
. "$(dirname "$0")/../lib/assert.sh"
R='${CLAUDE_PLUGIN_ROOT}/references/task-set.md'
n=0
t_begin "the reference exists and holds the rules"
f="$KIT/plugins/bearing/references/task-set.md"; assert_file "$f"
body="$(cat "$f")"
for h in "## Start" "## Branch names" "## State and progress" "## Merge order" "## One MR per repository" "## Finish"; do assert_contains "$body" "$h"; done
t_end
t_begin "the five skills cite it"
for s in start-task session-handoff definition-of-done merge-request autopilot; do
  n=$((n+1)); f="$KIT/plugins/bearing/skills/$s/SKILL.md"
  assert_contains "$(cat "$f")" "$R" "$s cites task-set.md"
  assert_eq 1 "$([ "$(wc -l < "$f")" -le 200 ] && echo 1 || echo 0)" "$s at most 200 lines"
done
assert_eq 5 "$n" "five skills checked"
t_end
t_summary
```

- [ ] **Step 2: Run it to see it fail**

Run: `chmod +x tests/unit/task_set_skills.sh && bash tests/unit/task_set_skills.sh`
Expected: FAIL (no reference, no citations).

- [ ] **Step 3: Write the reference** (`plugins/bearing/references/task-set.md`, about 60 lines, no commands to run; skills keep their commands in SKILL.md so `lint-tools` sees them)

Sections, each a few lines, content from spec C1 to C6: `# Task sets: one task across repositories` (what a set is, one session per repository and why: the sandbox and the `git -C` rule); `## Start` (start-task in each repository with the same id, name and `--repos` list; names from `docs/architecture/repo-plan.json` resolve to `../<name>` or the entry's `path`); `## Branch names` (the same `<type>/<ID>-<PascalName>` everywhere; one type for the whole set); `## State and progress` (the state file per repository, unchanged; the `## Repos` section identical in every member, item `<n>. <Name> (<path>)`; at most 8); `## Merge order` (Infrastructure, Server, Client by `git_path`, else the given order, confirmed once; each MR merges alone in order and leaves its default branch working; a lockstep change goes under Risk with `api-versioning` or `feature-flags`); `## One MR per repository` (the description's Task set block; merge after the previous one; the engineer merges, one at a time); `## Finish` (every member's progress Status `merged`; `progress.py set` shows it).

- [ ] **Step 4: Edit the five skills** (each a few lines; keep each at 200 or fewer)

- `start-task`: argument-hint gains `[--repos Name,Name,...] [--flow site]`; Inputs gains "repositories: `--repos`; with it, this is one member of a task set (`${CLAUDE_PLUGIN_ROOT}/references/task-set.md`)". Step 7 gains: "With `--repos`: ask the merge order once with AskUserQuestion (recommended: the order the reference gives), then `progress.py write --task <ID> --repo "<n>. <Name> (<path>)" ...` in the new branch's tree." Output contract gains the `Set:` line.
- `session-handoff`: in step 6, "With a `## Repos` section in the progress file, run `progress.py set --task <ID>` and add its rows under `## Set` in the handoff; Next names the repository the action is in (`${CLAUDE_PLUGIN_ROOT}/references/task-set.md`)."
- `definition-of-done`: the next item number after sub-project 3's last: "task set: `n/a` without a `## Repos` section in `docs/progress/<ID>.md`; else `python3 "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py" set --task <ID>`; `pass` when every repository before this one in the merge order is `ready` or `merged`, `fail` naming the others (`${CLAUDE_PLUGIN_ROOT}/references/task-set.md`)." Update the item count in Inputs ("the <n> items in step 3"). Grant `Bash(python3 *skills/session-handoff/scripts/progress.py*)`.
- `merge-request`: step 6 gains "With a `## Repos` section: add the Task set block (each repository, branch, order, `merge after <Name> | first`) per `${CLAUDE_PLUGIN_ROOT}/references/task-set.md`." Output contract gains the `Set:` line.
- `autopilot`: step 10 gains "When the repo plan has more than one entry, write the `## Repos` section from it in merge order and list each sibling's `start-task ... --repos` line in the report (`${CLAUDE_PLUGIN_ROOT}/references/task-set.md`)."; `references/review-smoke-and-mr.md` the same, with the `progress.py write` command.

- [ ] **Step 5: Run the tests and the lints**

Run: `bash tests/unit/task_set_skills.sh && make lint-skills lint-tools lint-skill-size lint-questions lint-plugin-size`
Expected: `task_set_skills.sh: 2 cases, <m> assertions, 0 failed`; `lint-questions: ... 0 in prose`; `lint-plugin-size:` shows `bearing <count+2> files`.

- [ ] **Step 6: Commit**

```bash
git add plugins/bearing/references/task-set.md plugins/bearing/skills/{start-task,session-handoff,definition-of-done,merge-request,autopilot} tests/unit/task_set_skills.sh
git commit -m "feat(task-set): one task across repositories: same branch, a Repos section, a merge order, one MR each"
```

---

### Task 10: The site flow

**Files:**
- Modify: `docs/flows.json` (`_about`; a new flow after the last one)
- Modify: `plugins/bearing/bin/brg-session` (`next-step`, line 105)
- Modify: `plugins/bearing/skills/start-task/SKILL.md` (Inputs: `--flow site`), `plugins/bearing/skills/workflow/SKILL.md` (stage table row)
- Modify: `site/src/pages/Home.tsx:5`, `site/src/lib/nav.ts:7`, `README.md:215,221`, `docs/INSTALL.md:306`, `bin/gen-guide.py:9`
- Generated: `plugins/bearing/bin/flow-steps.tsv`, `site/src/data/handbook.json`, `docs/WORKFLOW.md`, `docs/SKILLS.md`, `devguide/src/data/internals.json`
- Test: `tests/unit/session_resume.sh`

**Interfaces:**
- Produces: flow id `site`; `flow-steps.tsv` rows `site<TAB>n<TAB>skill`.
- Produces: `brg-session next-step` uses flow `site` when `.bearing/config.json` has `"flow": "site"` and the branch is not `bugfix/*|fix/*|hotfix/*`.

- [ ] **Step 1: Write the failing tests** (in `tests/unit/session_resume.sh`, after the `step` and `ran` helpers)

```bash
t_begin "a site repository follows the site flow on a feature branch"
git -C "$repo" checkout -q -b feature/TASK-50-Landing
mkdir -p "$repo/.bearing"; printf '{"flow": "site"}\n' > "$repo/.bearing/config.json"
assert_exit 0 in_repo next-step
assert_eq "$(step site 1)" "$T_OUT"
assert_eq "start-task" "$(step site 1)" "site step 1"
ran "bearing:start-task"
assert_exit 0 in_repo next-step
assert_eq "brainstorming" "$T_OUT" "site step 2"
t_end

t_begin "a bugfix branch in a site repository follows the bugfix flow"
git -C "$repo" checkout -q -b bugfix/TASK-51-Typo
assert_exit 0 in_repo next-step
assert_eq "$(step bugfix 1)" "$T_OUT"
rm -f "$repo/.bearing/config.json"
t_end
```

- [ ] **Step 2: Run them to see them fail**

Run: `bash tests/unit/session_resume.sh`
Expected: FAIL, `step site 1` is empty.

- [ ] **Step 3: Add the flow**

A new entry in `flows`, after the last flow: id `site`, title "Marketing site or landing page", tagline "From a goal and a page brief to a fast, accessible page, reviewed and shipped.", when "A landing page, a marketing site or a docs-style site: content and screens, no product backend, no API to design.". Steps exactly as spec B (ids `s-task`, `s-brief`, branch `s-repo`, `s-direction`, branch `s-system`, `s-screens`, `s-build`, branch `s-events` and `s-privacy`, `s-a11y`, `s-perf`, `s-critique`, `s-review`, `s-dod`, `s-mr`, `s-verify` with `"optional": true`); every step with `id`, `title`, `skill`, `pack`, `does`, `output`, `why` in the house style and no ranking words. `s-mr` uses the qualified wording from Task 7. `_about` names the new count of flows.

- [ ] **Step 4: Make `next-step` follow it; start-task and workflow name it**

In `brg-session` `next-step`, replace line 105 with:

```bash
    case "$branch" in
      bugfix/*|fix/*|hotfix/*) flow=bugfix;;
      *) flow=feature
         cf="$(git rev-parse --show-toplevel 2>/dev/null)/.bearing/config.json"
         [ -f "$cf" ] && [ "$(sed -n 's/.*"flow"[[:space:]]*:[[:space:]]*"\([a-z]*\)".*/\1/p' "$cf" | head -1)" = site ] && flow=site;;
    esac
```

(No jq here: the bash32 CI image may lack it, and `.bearing/config.json` is written by `brg-config` with one key per line. After the rebase, sub-project 4's `genai` line stays after this and applies only when `flow` is still `feature`.) `start-task` Inputs: "flow: `--flow site`, or the request names a landing page or marketing site and the user confirms with AskUserQuestion; record it with `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-config" set flow site` (the project answer; every later task in this repository follows the site flow)". `workflow` table: after the GenAI row, `| Site | a landing page or marketing site: the site flow (\`start-task --flow site\`); \`screen-design\`, \`accessibility\`, \`performance\`, \`branch-review\` |`. Colour maps: `site: "var(--gs)"`. Prose counts: the new number of flows and the new flow's name.

- [ ] **Step 5: Regenerate, run the tests and the gate parts**

Run: `make docs && bash tests/unit/session_resume.sh && make lint-docs lint-skills lint-tools lint-skill-size`
Expected: `site data: <n> skills, <f> flows (...)` with no problems; `gen-flow-steps: <f> flows, <s> steps`; `session_resume.sh: ... 0 failed`; `lint-docs: 5 generated docs up to date`.

- [ ] **Step 6: Commit**

```bash
git add docs/flows.json plugins/bearing/bin/brg-session plugins/bearing/bin/flow-steps.tsv plugins/bearing/skills/start-task plugins/bearing/skills/workflow site devguide/src/data docs README.md bin/gen-guide.py tests/unit/session_resume.sh
git commit -m "feat(flows): a site flow for landing pages and marketing sites, chosen per repository"
```

---

### Task 11: Eval cases for the changed behaviour

**Files:**
- Modify: `evals/merge-request/evals.json`, `evals/start-task/evals.json`, `evals/workflow/evals.json` (one case each, next free `id`; fixtures under each `files/` as the existing cases do)

**Interfaces:**
- Produces: three cases in skill-creator's schema (`id`, `name`, `prompt`, `expected_output`, `files`, `expectations`).

- [ ] **Step 1: Write the cases**

- `merge-request`, `opt-in-push-request`: a fixture repository on `feature/PAY-300-Receipts` with a passing `make check`, `.bearing/state/.push-optin` holding `on` and a local bare `origin`; prompt "Get the MR ready for the receipts branch." Expectations: `brg-push check` ran and printed `push-check: 9 conditions, 9 met`; `brg-push request` ran; no `git push` ran in the transcript; the report's `Push:` line says `requested (opt-in)`; the push command is not printed as the engineer's next step.
- `start-task`, `task-set-two-repos`: a parent folder with `ShopApi` and `ShopWeb` and a repo plan in `ShopApi`; prompt "Start SHOP-12 OrderNotes across ShopApi and ShopWeb." Expectations: one branch `feature/SHOP-12-OrderNotes` in the session's repository only; one AskUserQuestion for the merge order with ShopApi first recommended; `docs/progress/SHOP-12.md` has a `## Repos` section `1. ShopApi`, `2. ShopWeb`; the report prints the `start-task SHOP-12 OrderNotes --repos ShopApi,ShopWeb` line for the sibling; nothing written in the sibling.
- `workflow`, `site-repository-next-step`: a fixture with `.bearing/config.json` `{"flow": "site"}`, branch `feature/WEB-4-Pricing`, timeline showing `start-task` and `brainstorming`; prompt "what next?". Expectations: leads with `design-directions`; does not name `prd`, `high-level-design` or `openapi-spec`.

- [ ] **Step 2: Run the eval lints**

Run: `make lint-evals lint-json`
Expected: `lint-evals:` reports the counts with 0 problems.

- [ ] **Step 3: Commit**

```bash
git add evals/merge-request evals/start-task evals/workflow
git commit -m "test(evals): opt-in push request, a two-repository task set, the site flow's next step"
```

---

### Task 12: CHANGELOG and the full gate

**Files:**
- Modify: `CHANGELOG.md` (under `## [Unreleased]`)

- [ ] **Step 1: Write the entries**

Added: opt-in push (`BEARING_AUTO_PUSH` in `bearing.env`, default empty; `brg-push check|request|status`; the Stop hook pushes the current feature branch after the gate, never main, master, develop, release branches or tags, never forced, never merged); the `site` flow for landing pages and marketing sites (`start-task --flow site`); task sets across repositories (`start-task --repos`, the `## Repos` progress section, `progress.py set`, the merge order, `references/task-set.md`); a definition-of-done item for task sets. Changed: the pre-push hook allows an opted-in agent push of a feature branch fast-forward and refuses agent tag pushes; `brg-config` refuses to set the auto-push key; the settings template denies `Edit(~/.config/bearing/**)` and `brg-push run`; AGENTS.md rule 2 names the exception; merge-request and autopilot descriptions say "pushes only where opted in"; autopilot's `mr` gate accepts a push by `brg-push`. Note for existing repositories: copy `.githooks/lib.sh` and `pre-push` from the template (or run `onboard-repo`) before opting a repository in; until then `brg-push check` reports `no pre-push` and nothing is pushed.

- [ ] **Step 2: Run the full gate**

Run: `make docs && git status --short`
Expected: no generated file changes (Tasks 7 and 10 committed them).
Run: `make check 2>&1 | tail -25`
Expected: the counts lines, among them `lint-plugin-size: ... bearing <pre-branch count + 2> files`, `lint-skill-size: ...` with no new allow entry, `tests: <n> run, 0 failed`, and last line `check: passed`.

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md
git commit -m "docs(changelog): opt-in push, site flow and task sets under Unreleased"
```

- [ ] **Step 4: Hand over (Bearing never pushes this branch)**

Run `definition-of-done`, then `merge-request` to draft the description with Changed, Verified (each lint and test count line), Not done, Noticed. Print for the engineer: `make gate && git push -u origin feat/QueuedRequests`.
