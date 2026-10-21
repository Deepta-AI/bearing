# Queued Requests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Three queued requests: an opt-in push of the current feature branch after the gate (default off), a light flow for marketing sites and landing pages, and explicit multi-repo task sets, with the smallest change to the existing skills.

**Architecture:** One new script, `plugins/bearing/bin/brg-push`, decides and performs the only push Bearing makes; skills may `check` and `request`, and only `brg-guard stop-gate` (a hook, outside the sandbox) may `run` it. The raw `git push` stays blocked by the guard, the settings deny and the sandbox. (amended 2026-10-18: clean-clone push) `run` pushes from a fresh `git clone --no-local` of the task branch under a cleared environment, to the exact URL listed in the engineer's `bearing.env`, so no repository hook, Makefile or git config runs outside the sandbox; the repository's pre-push hook refuses every agent push, as before this branch. The site flow is data in `docs/flows.json`, chosen per repository by a project config key. Task sets are a `## Repos` section in each repository's committed progress file, read by a new `progress.py set`, with the rules in one new shared reference, `plugins/bearing/references/task-set.md`.

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
- (amended 2026-10-18: clean-clone push) outside the sandbox `brg-push` runs only `git config --file` reads, `rev-parse HEAD` inside its clone, and these two commands, every one under `env -i PATH=/usr/bin:/bin HOME=<passwd home> SSH_AUTH_SOCK=<value> GIT_TERMINAL_PROMPT=0`: `git -c core.hooksPath=/dev/null clone --no-local --single-branch --branch <branch> --no-tags --no-checkout -- <repository path> <tmp>/c`, then `git -C <tmp>/c -c core.hooksPath=/dev/null push --no-follow-tags <entry URL> HEAD:refs/heads/<branch>`; then it deletes `<tmp>`. No force, no tags, no `--set-upstream`, no other refspec, never origin's configured url, anywhere. Origin's url is read with `git config --file <git common dir>/config`, never by a git command run in the working repository.
- (amended 2026-10-18: clean-clone push) `BEARING_AUTO_PUSH` entries are full push URLs (ssh, scp-style or https; an absolute path or `file://` as the test form). It is read from `<passwd home>/.config/bearing/bearing.env` only (`passwd_home`), never from `BEARING_ENV`, `XDG_CONFIG_HOME`, `HOME` or an environment variable of that name. `brg-push` prints an entry's `url_key`, never the entry (an https entry may hold a token).
- Hook steps added here exit 0 on their own failure and log `<gate> not-run <reason>`; only the existing Stop gate may exit 2.
- State writes are atomic: `<file>.tmp`, then `mv`.
- Commits: Conventional Commits, no attribution trailer of any kind. Bearing never pushes this branch.
- After touching a skill, `docs/flows.json` or `bin/gen-guide.py`: `make docs` and commit what it regenerates; never hand-edit `docs/SKILLS.md`, `site/src/data/handbook.json`, `devguide/src/data/internals.json`, `plugins/bearing/bin/flow-steps.tsv`.
- The repository gate: `make check` ends with `check: passed`.

## Review Focus

1. The agent must have no path to a push it can trigger alone: `brg-push run` from Bash is denied by the guard, `bearing.env` cannot be written by `brg-config`, Edit, or the sandbox, and a `bearing.env` changed during the session is refused. Pinned in Tasks 1, 3 and 5. (amended 2026-10-18: clean-clone push) And no agent-editable code runs at push time: no repository hook, no `make`, no `.git/config` key, no exported variable. Pinned in Task 3.
2. A stale request must never fire: a request for another sha, or a request left after a refusal, pushes nothing. Pinned in Task 3.
3. (amended 2026-10-18: clean-clone push) The repository's pre-push hook takes no part in the opt-in push and refuses every agent push, a tag included; its opt-in code is gone, so a repository's hook version does not matter. Pinned in Task 4.
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
| `plugins/bearing/templates/repo/.githooks/{lib.sh,pre-push}` and `plugins/bearing/skills/git-hooks/templates/.githooks/{lib.sh,pre-push}` (modify) | (amended 2026-10-18: clean-clone push) no opt-in path; an agent push or tag is refused |
| `plugins/bearing/templates/repo/.claude/settings.json` (modify) | deny `Edit(~/.config/bearing/**)`, `Edit(~/.gitconfig)`, `Edit(~/.config/git/**)` and `Bash(bash *bin/brg-push run*)`; `_readme` (amended 2026-10-18: clean-clone push) |
| `plugins/bearing/templates/repo/AGENTS.md` (modify) | rule 2 names the exception |
| `plugins/bearing/templates/user/bearing.env` (modify) | the commented key |
| `plugins/bearing/hooks/hooks.json` (modify) | description |
| `plugins/bearing/skills/session-handoff/scripts/progress.py`, `templates/progress.md` (modify) | `--repo`, `## Repos`, `set` |
| `plugins/bearing/skills/{merge-request,autopilot,start-task,session-handoff,definition-of-done,workflow}/SKILL.md` (modify) | push request, task set, site flow |
| `plugins/bearing/skills/autopilot/references/review-smoke-and-mr.md` (modify) | push request, task set |
| `docs/flows.json` (modify) | the `site` flow; the `mr` step wording |
| `bin/gen-guide.py`, `README.md`, `CONTRIBUTING.md`, `docs/INSTALL.md`, `docs/WORKFLOW.md` (hand-written lines), `devguide/src/pages/{Architecture,Autopilot,Start,Home}.tsx`, `site/src/pages/{Guides,Home}.tsx`, `site/src/lib/nav.ts` (modify) | claims and flow counts |
| `tests/unit/push_check.sh`, `push_run.sh`, `githooks_pre_push.sh`, `push_settings.sh`, `push_claims.sh`, `task_set_skills.sh` (create) | named in each task |
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

**Result (amended 2026-10-18: clean-clone push).** Run by the engineer on 2026-10-18 (R8): the Stop hook pushed to a local bare remote (`rc=0`), read `~/.config/bearing` and saw the ssh agent; the model's Bash `ls` of `~/.config/bearing` was blocked. A network ssh push was not tried (local remote only, by design). An untrusted workspace ignores `permissions.allow` but still runs the Stop hook. The Stop hook stays the trigger; what it runs is the clean-clone push of Task 3.

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

(amended 2026-10-18: clean-clone push) Whole task rewritten: entries are full push URLs, `url_key` and `passwd_home` land here from the hook, the `pre-push` condition is gone (8 conditions), and the gate reads `git status -z`.

**Files:**
- Create: `plugins/bearing/bin/brg-push` (mode 755)
- Test: `tests/unit/push_check.sh` (create, mode 755)
- Source of the moved functions: `url_key` and `passwd_home` as they stand in `plugins/bearing/templates/repo/.githooks/lib.sh` at `2baa793` (lines 43-77 and 127-139); Task 4 deletes them from the hook, so copy them from that commit (`git show 2baa793:plugins/bearing/templates/repo/.githooks/lib.sh`).

**Interfaces:**
- Produces: `brg-push check` prints one line per condition, `ok <name>: <detail>` or `no <name>: <detail>`, for the eight conditions `opt-in origin branch not-protected clean ahead gate fast-forward` in that order, then `push-check: 8 conditions, <M> met`; exit 0 when 8 met, 1 otherwise, 2 outside a git repository with stderr `brg-push: not a git repository; 0 conditions checked`.
- Produces: `brg-push optin-record` writes `.bearing/state/.push-optin` holding `on` or `off` (atomic) and prints nothing; exit 0 always. It runs from the SessionStart hook, outside the sandbox, so it runs no git command in the working repository: origin's url comes from `origin_url`.
- Produces (used by Task 3): shell functions
  - `url_key <url>`: the round-2 normalisation, unchanged (ssh, scp-style, https; absolute path or `file://` as `localhost/<path>`; other schemes, `<helper>::` forms and a non-numeric port exit 1; a non-default port kept).
  - `passwd_home`: unchanged from the hook.
  - `git_common_dir`: reads `<root>/.git` as text: a directory is the answer; a file `gitdir: <p>` gives `<p>`, then `<p>/commondir` when present (relative to `<p>`). No git command.
  - `cleanenv <cmd>`: `env -i PATH=/usr/bin:/bin HOME="$home" ${SSH_AUTH_SOCK:+SSH_AUTH_SOCK="$SSH_AUTH_SOCK"} GIT_TERMINAL_PROMPT=0 "$@"`, `home` from `passwd_home`. Every git command `optin-record` and `run` run goes through it.
  - `origin_url`: `cleanenv git config --file "$(git_common_dir)/config" --get remote.origin.url`, run with the working directory set to an empty temporary directory (includes are not followed).
  - `entry_for`: reads `BEARING_AUTO_PUSH` from `<passwd home>/.config/bearing/bearing.env` only (last line wins, quotes stripped, commas as spaces, `set -f` around the loop), prints the first entry whose `url_key` equals `url_key "$(origin_url)"`, exit 1 when none. An entry with no key (a `<host>/<path>` from the first fix round, `http://`) matches nothing.
- The script ends with the single line `main "$@"`, so a test can copy it, drop that line, append a `passwd_home` override and the line again: the one seam, as the hook tests used.

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bash
# tests/unit/push_check.sh: brg-push check prints one line per condition and
# the count, refuses outside a repository, and names each unmet condition;
# optin-record writes on or off from the passwd-home bearing.env, matching a
# full push URL entry to origin by url_key, never from the environment.
# bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
unset BEARING_ENV BEARING_AUTO_PUSH
home="$(tmpdir)"; mkdir -p "$home/.config/bearing"; envf="$home/.config/bearing/bearing.env"
# brg-push with the passwd home pointed at the fixture: the one seam.
P="$(tmpdir)/brg-push"
sed '$d' "$KIT/plugins/bearing/bin/brg-push" > "$P"
printf "passwd_home() { printf '%%s\\\\n' '%s'; }\nmain \"\$@\"\n" "$home" >> "$P"

setup() { # a repository on feature/ABC-1-Thing, one commit ahead of origin/main, check passed
  repo="$(tmpdir)"; remote="$(tmpdir)/remote.git"
  git init -q --bare "$remote"
  git -C "$repo" init -q -b main
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  printf '.bearing/state/\n' > "$repo/.gitignore"
  printf 'check:\n\t@mkdir -p .bearing/state && touch .bearing/state/.check-passed\n' > "$repo/Makefile"
  git -C "$repo" add .gitignore Makefile; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" remote add origin "$remote"; git -C "$repo" push -q origin main 2>/dev/null
  git -C "$repo" switch -q -c feature/ABC-1-Thing
  printf 'x\n' > "$repo/a.txt"; git -C "$repo" add a.txt; git -C "$repo" commit -q -m "feat: a [ABC-1]"
  mkdir -p "$repo/.bearing/state"; sleep 1; touch "$repo/.bearing/state/.check-passed"
  printf 'BEARING_AUTO_PUSH="file://%s"\n' "$remote" > "$envf"
  ( cd "$repo" && bash "$P" optin-record )
}
in_repo() { ( cd "$repo" && bash "$P" "$@" ) }
# The functions without main, to call one directly (bash 3.2 cannot source <(...)).
fns="$(tmpdir)/fns.sh"; sed '$d' "$P" > "$fns"
kitfns="$(tmpdir)/kitfns.sh"; sed '$d' "$KIT/plugins/bearing/bin/brg-push" > "$kitfns"
key() { bash -c '. "$1"; url_key "$2"' _ "$fns" "$1"; }

t_begin "outside a git repository: exit 2 and 0 conditions"
d="$(tmpdir)"
assert_exit 2 bash -c "cd '$d' && bash '$P' check"
assert_contains "$T_OUT" "0 conditions checked"
t_end

t_begin "everything met: eight ok lines and the count"
setup
assert_exit 0 in_repo check
assert_contains "$T_OUT" "ok opt-in:"
assert_contains "$T_OUT" "ok origin: localhost/"
assert_contains "$T_OUT" "ok gate: 1 file(s) compared"
assert_contains "$T_OUT" "push-check: 8 conditions, 8 met"
assert_not_contains "$T_OUT" "pre-push"
t_end

t_begin "origin's key not listed in bearing.env"
setup; printf 'BEARING_AUTO_PUSH="git@git.example.test:other/repo.git"\n' > "$envf"; ( cd "$repo" && bash "$P" optin-record )
assert_exit 1 in_repo check
assert_contains "$T_OUT" "no opt-in:"
t_end

t_begin "a host/path entry is not a push URL and does not opt in"
setup; p="${remote%.git}"; printf 'BEARING_AUTO_PUSH="localhost/%s"\n' "${p#/}" > "$envf"; ( cd "$repo" && bash "$P" optin-record )
assert_eq off "$(cat "$repo/.bearing/state/.push-optin")"
t_end

t_begin "an environment variable does not opt in"
setup; : > "$envf"; ( cd "$repo" && BEARING_AUTO_PUSH="file://$remote" bash "$P" optin-record )
assert_exit 1 in_repo check
assert_contains "$T_OUT" "no opt-in:"
t_end

t_begin "a self-supplied BEARING_ENV, XDG_CONFIG_HOME or HOME does not opt in"
setup; : > "$envf"
fake="$(tmpdir)"; mkdir -p "$fake/.config/bearing" "$fake/bearing"
printf 'BEARING_AUTO_PUSH="file://%s"\n' "$remote" | tee "$fake/.config/bearing/bearing.env" "$fake/bearing/bearing.env" > "$fake/env"
for v in "BEARING_ENV=$fake/env" "XDG_CONFIG_HOME=$fake" "HOME=$fake"; do
  ( cd "$repo" && env "$v" bash "$P" optin-record )
  assert_eq off "$(cat "$repo/.bearing/state/.push-optin")" "$v"
done
t_end

t_begin "passwd_home ignores HOME"
real="$(bash -c '. "$1"; passwd_home' _ "$kitfns")"
assert_eq "$real" "$(HOME=/tmp bash -c '. "$1"; passwd_home' _ "$kitfns")"
t_end

t_begin "url_key normalises https, ssh and scp-style URLs the same way"
for u in git@Git.Example.Test:group/shop.git ssh://git@git.example.test:22/group/shop.git https://user:tok@git.example.test/group/shop/; do
  assert_eq "git.example.test/group/shop" "$(key "$u")" "$u"
done
assert_eq "localhost/srv/r" "$(key /srv/r.git)" "local path"
t_end

t_begin "url_key keeps a port other than the default"
assert_eq "git.example.test:2222/group/shop" "$(key ssh://git@git.example.test:2222/group/shop.git)"
assert_eq "git.example.test:8443/group/shop" "$(key https://git.example.test:8443/group/shop)"
t_end

t_begin "url_key refuses http, git, other schemes and helper forms"
for u in http://h/g/r git://h/g/r git+ssh://h/g/r ssh+git://h/g/r ftp://h/g/r 'ext::sh -c x' 'ssh://h:x/g/r' relative/path; do
  assert_exit 1 key "$u"
done
t_end

t_begin "optin-record reads origin's url as a file, not through the repository"
setup; printf 'not a ref\n' > "$repo/.git/HEAD"   # git no longer treats it as a repository
( cd "$repo" && GIT_DIR=/nonexistent bash "$P" optin-record )
assert_eq on "$(cat "$repo/.bearing/state/.push-optin")"
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

t_begin "an untracked file with a space in its name counts for the gate"
setup; sleep 1; printf 'n\n' > "$repo/new file.txt"
assert_exit 1 in_repo check; assert_contains "$T_OUT" "no gate: 1 of 2 file(s) newer than the last make check"
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

t_summary
```

- [ ] **Step 2: Run it to see it fail**

Run: `chmod +x tests/unit/push_check.sh && bash tests/unit/push_check.sh`
Expected: FAIL on every case (`brg-push` does not exist).

- [ ] **Step 3: Implement `brg-push` (check and optin-record)**

Header comment: what it is, the five subcommands with their exit codes, "the only git push Bearing runs, from a fresh clone, never from the working tree", "optin-record and run run outside the sandbox and run no git command in the working repository", "run is for the Stop hook; the guard refuses it from Bash", bash 3.2. Body outline (functions first, `main "$@"` last):

```bash
#!/usr/bin/env bash
set -u
here="$(cd "$(dirname "$0")" && pwd)"
TASK_RE='^(feature|bugfix|hotfix|chore|docs)/[A-Z][A-Z0-9]*(-[0-9]+)+-[A-Za-z0-9]+$'
# url_key, passwd_home: copied from .githooks/lib.sh at 2baa793, comments kept
git_common_dir() { # <root>/.git read as text; no git command
  local g="$root/.git" p c
  [ -d "$g" ] && { printf '%s\n' "$g"; return 0; }
  [ -f "$g" ] || return 1
  p="$(sed -n 's/^gitdir: //p' "$g" | head -1)"; [ -n "$p" ] || return 1
  case "$p" in (/*) ;; (*) p="$root/$p";; esac
  if [ -f "$p/commondir" ]; then c="$(head -1 "$p/commondir")"; case "$c" in (/*) p="$c";; (*) p="$p/$c";; esac; fi
  printf '%s\n' "$p"
}
cleanenv() { env -i PATH=/usr/bin:/bin HOME="$home" ${SSH_AUTH_SOCK:+SSH_AUTH_SOCK="$SSH_AUTH_SOCK"} GIT_TERMINAL_PROMPT=0 "$@"; }
origin_url() { local d; d="$(git_common_dir)" || return 1; ( cd "$empty" && cleanenv git config --file "$d/config" --get remote.origin.url ); }
entry_for() { # prints the listed entry for origin's key; the file only, never the environment
  local envf line v x k ok=1
  home="$(passwd_home)" || return 1; envf="$home/.config/bearing/bearing.env"
  k="$(url_key "$(origin_url)")" || return 1
  [ -f "$envf" ] || return 1
  line="$(grep -E '^BEARING_AUTO_PUSH[[:space:]]*=' "$envf" | tail -1)"; [ -n "$line" ] || return 1
  v="${line#*=}"; v="${v%%#*}"; v="$(printf '%s' "$v" | tr -d "\"'" | tr ',' ' ')"
  set -f
  for x in $v; do [ "$(url_key "$x")" = "$k" ] && { printf '%s\n' "$x"; ok=0; break; }; done
  set +f
  return "$ok"
}
n=0; met=0
cond() { n=$((n+1)); if [ "$2" -eq 0 ]; then met=$((met+1)); echo "ok $1: $3"; else echo "no $1: $3"; fi; }
base_ref() { local b; for b in origin/develop origin/main origin/master; do git -C "$root" rev-parse -q --verify "$b" >/dev/null && { echo "$b"; return 0; }; done; return 1; }
main() {
  sub="${1:-}"; [ $# -gt 0 ] && shift
  empty="$(mktemp -d "${TMPDIR:-/tmp}/brg-push.XXXXXX")"; trap 'rm -rf "$empty"' EXIT
  case "$sub" in
    (optin-record) root="${CLAUDE_PROJECT_DIR:-$PWD}" ;;   # no git rev-parse here: outside the sandbox
    (*) root="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "brg-push: not a git repository; 0 conditions checked" >&2; exit 2; } ;;
  esac
  st="$root/.bearing/state"
  ...
}
main "$@"
```

`check_conditions` (used by `check` and by `request` in Task 3; it runs in the sandbox) evaluates, in order:
`opt-in` (`$st/.push-optin` reads `on`), `origin` (`url_key "$(git -C "$root" remote get-url origin)"` succeeds; detail the key), `branch` (`git symbolic-ref -q --short HEAD`; detached prints `detached`; must match `$TASK_RE` with `grep -Eq`), `not-protected` (not `main|master|develop|release/*`, and not a word of `PROTECTED_BRANCHES` read with `sed -n "s/^PROTECTED_BRANCHES='\(.*\)'.*/\1/p"` from `.githooks/lib.sh` when present; never sourced), `clean` (`git status --porcelain --untracked-files=no` empty; detail the count), `ahead` (`git rev-list --count <base>..HEAD` at least 1; no base is `no ahead: no origin/develop, origin/main or origin/master`), `gate` (files: `git diff -z --name-only <base>...HEAD` plus the paths of `git status -z --untracked-files=all` (a rename record's second path skipped), read with `while IFS= read -r -d '' f`, paths under `.bearing/` skipped (R3), sorted unique, existing only; zero files is `no gate: 0 files on the branch`; no marker is `no gate: make check has never passed`; else count those `-nt` the marker: zero is `ok gate: <k> file(s) compared`, otherwise `no gate: <j> of <k> file(s) newer than the last make check`; reason order per R12), `fast-forward` (no `refs/remotes/origin/<branch>`, or `git merge-base --is-ancestor origin/<branch> HEAD`).

`check)`: run `check_conditions`, print `push-check: $n conditions, $met met`, exit 0 when equal, else 1.
`optin-record)`: `mkdir -p "$st"`; `if entry_for >/dev/null; then v=on; else v=off; fi`; write `$st/.push-optin.tmp`, `mv`; `exit 0`. It never prints the entry.
Unknown or empty subcommand: usage on stderr, exit 2.

- [ ] **Step 4: Run the tests and the lints**

Run: `bash tests/unit/push_check.sh && make lint-shell lint-portable lint-plugin-size`
Expected: `push_check.sh: 18 cases, <m> assertions, 0 failed`; `lint-shell: <n> scripts` (one more than before); `lint-portable` clean; `lint-plugin-size:` shows `bearing <count+1> files`.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-push tests/unit/push_check.sh
git commit -m "feat(push): brg-push check names each condition; the opt-in is a push URL matched to origin by key"
```

---

### Task 3: `request`, `run`, `status`; the guard row; the Stop gate runs it

(amended 2026-10-18: clean-clone push) `run` rewritten: it judges the request, the opt-in and the engineer's global transport settings, then clones the branch fresh and pushes from the clone to the listed entry. The R14 case (the push passes the real pre-push hook) is replaced by its opposite: no repository hook, Makefile or config runs at push time. The guard and Stop gate parts are unchanged.

**Files:**
- Modify: `plugins/bearing/bin/brg-push`
- Modify: `plugins/bearing/bin/brg-guard` (verb rows near line 69; `stop-gate` `passed` at line 1672; `session` after the session mark near line 1574; `task-id` near line 1550; header comment line 64)
- Test: `tests/unit/push_run.sh` (create), `tests/unit/guard_deny_table.sh`
- Source of the moved function: `transport_redirect` as it stands in `plugins/bearing/templates/repo/.githooks/lib.sh` at `2baa793` (lines 85-125), adapted below.

**Interfaces:**
- Consumes: `check_conditions`, `entry_for`, `origin_url`, `url_key`, `passwd_home`, `TASK_RE` (Task 2).
- Produces: `brg-push request` exits 1 with the check output when a condition is unmet; else writes `.bearing/state/push-request` (`branch=<b>`, `sha=<HEAD>`, `time=<UTC>`) atomically and prints `push: requested <branch> <short sha>`.
- Produces: `brg-push run --id <sid> [--foreground]`, from the Stop hook, outside the sandbox, running no git command in the working repository. Conditions, in order: `request` (file present with `branch=` and a 40-hex `sha=`; absent prints `no request: none`), `branch` (`$TASK_RE`), `not-protected` (not `main|master|develop|release/*`, nor a word of `PROTECTED_BRANCHES` read as text from `.githooks/lib.sh`), `opt-in` (`entry_for`; the detail prints the key), `opt-in-age` (session mark `$st/.session-<id>` exists and the passwd-home `bearing.env` is not `-nt` it), `marker` (`$st/.check-passed` exists), `transport` (`transport_redirect` names nothing), and with `--foreground` only, `clone` (the clone succeeded and its `HEAD` equals `sha=`). Without `--foreground` it prints `push-run: 7 conditions before the clone, <M> met`; all met: starts `nohup bash "$0" run --id "$sid" --foreground < /dev/null >> "$st/push.log" 2>&1 &` (R7), logs the start time, prints `bearing push: started for <branch>`, exits 0. With `--foreground` it prints `push-run: 8 conditions, <M> met` and pushes. On any unmet: deletes the request, writes `push-result` `push refused: <first unmet>`, logs `push refused`, exits 1. After the push: `push-result` `pushed <branch> <sha> to <key> <UTC time>` or `push failed: <last stderr line>`, logs `push pushed|failed`. No line it writes holds the entry URL.
- Produces: `transport_redirect <entry URL>` (adapted): run in the empty directory under the cleared environment, so it sees only the system and global config; prints the first key that would redirect the push, or returns 1. Keys: `core.sshCommand` other than `ssh`; non-empty `core.gitProxy`, `http.proxy`, `https.proxy`, `http.<url>.proxy`, `http.curloptResolve`; `http.sslVerify` or `http.<url>.sslVerify` false; a `url.<base>.insteadOf` or `pushInsteadOf` whose value is a prefix of the entry. The environment branch of the round-2 function and `BRG_PUSH_PARAMS` are dropped: the environment is cleared.
- Produces: the clone and the push, the only git commands `run` runs besides `git config --file` and `git -C "$tmp/c" rev-parse HEAD` in the clone, each through `cleanenv` (Task 2):
  `cleanenv git -c core.hooksPath=/dev/null clone -q --no-local --single-branch --branch "$branch" --no-tags --no-checkout -- "$root" "$tmp/c"` and
  `cleanenv git -C "$tmp/c" -c core.hooksPath=/dev/null push --no-follow-tags "$entry" "HEAD:refs/heads/$branch"`, with `tmp="$(mktemp -d ...)"` removed by the `EXIT` trap.
- Produces: `brg-push status` prints the `push-result` line or `push: none`; with `--unseen` prints it only when `.bearing/state/.push-result-seen` is older, then touches that file.
- Produces: `brg-guard command 'brg-push run ...'` exits 2 with `Bearing blocked 'brg-push run (the Stop hook runs it)'`.
- Produces: `brg-guard stop-gate` on `passed` with a request present and `brg-push` beside it prints the `run` line; `brg-guard session` runs `optin-record` and prints `status --unseen`; `brg-guard task-id` prints `status --unseen`.

- [ ] **Step 1: Write the failing tests**

`tests/unit/push_run.sh`: copy `setup` and `in_repo` from Task 2 (tests do not source each other). The seam differs: copy the whole plugin, `pb="$(tmpdir)/bearing"; cp -R "$KIT/plugins/bearing/." "$pb/"`, rewrite `$pb/bin/brg-push` with the `passwd_home` override as Task 2 does, and set `P="$pb/bin/brg-push"` and `GUARD="$pb/bin/brg-guard"`, so `stop-gate` finds the seamed script beside the guard. Plus a session mark and a canary helper:

```bash
mark() { touch "$repo/.bearing/state/.session-s1"; }
none_ran() { # no canary under the fixture: no repository code ran
  assert_eq "" "$(find "$canary" -type f 2>/dev/null)" "no repository code ran"
}
canary="$(tmpdir)/canary"; mkdir -p "$canary"

t_begin "request needs every condition"
setup; git -C "$repo" switch -q main
assert_exit 1 in_repo request
assert_eq 0 "$([ -f "$repo/.bearing/state/push-request" ] && echo 1 || echo 0)" "no request written on main"
t_end

t_begin "request then run --foreground pushes the branch from a clone and nothing else"
setup; git -C "$repo" tag v9.9.9; sleep 1; mark
assert_exit 0 in_repo request
assert_contains "$T_OUT" "push: requested feature/ABC-1-Thing"
assert_exit 0 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "push-run: 8 conditions, 8 met"
assert_eq "$(git -C "$repo" rev-parse HEAD)" "$(git -C "$remote" rev-parse refs/heads/feature/ABC-1-Thing)"
assert_eq "" "$(git -C "$remote" tag)" "no tag reached the remote"
assert_contains "$(cat "$repo/.bearing/state/push-result")" "pushed feature/ABC-1-Thing $(git -C "$repo" rev-parse HEAD) to localhost/"
assert_not_contains "$(cat "$repo/.bearing/state/push-result" "$repo/.bearing/state/push.log" 2>/dev/null)" "file://"
assert_eq "" "$(git -C "$repo" config --get branch.feature/ABC-1-Thing.remote)" "no upstream set in the working repository"
assert_eq 0 "$([ -f "$repo/.bearing/state/push-request" ] && echo 1 || echo 0)" "request consumed"
assert_contains "$(cat "$repo/.bearing/state/gates.log" 2>/dev/null)" "	push	pushed	"
t_end

t_begin "no repository hook, Makefile, git config or exported variable runs at push time"
setup
printf 'check:\n\t@touch %s/make\n' "$canary" > "$repo/Makefile"; git -C "$repo" commit -q -am "chore: m [ABC-1]"
sleep 1; touch "$repo/.bearing/state/.check-passed"; mark; in_repo request >/dev/null
# The traps go in after the request: request runs in the sandbox, where they are harmless.
mkdir -p "$repo/.githooks"; cp -R "$KIT/plugins/bearing/templates/repo/.githooks/." "$repo/.githooks/"
for h in pre-push lib.sh; do printf '\ntouch %s/hook-%s\n' "$canary" "$h" >> "$repo/.githooks/$h"; done
git -C "$repo" config core.hooksPath .githooks
git -C "$repo" config core.sshCommand "touch $canary/sshcommand; ssh"
git -C "$repo" config credential.helper "!touch $canary/credential"
git -C "$repo" config core.fsmonitor "touch $canary/fsmonitor"
evil="$(tmpdir)/evil.git"; git init -q --bare "$evil"
git -C "$repo" config "url.file://$evil.pushInsteadOf" "file://$remote"
assert_exit 0 bash -c "cd '$repo' && GIT_SSH_COMMAND='touch $canary/env' GIT_CONFIG_PARAMETERS=\"'core.hooksPath'='.githooks'\" GIT_DIR=/nonexistent bash '$P' run --id s1 --foreground"
assert_eq "$(git -C "$repo" rev-parse HEAD)" "$(git -C "$remote" rev-parse refs/heads/feature/ABC-1-Thing)" "landed at the listed entry"
assert_eq "" "$(git --git-dir="$evil" for-each-ref)" "nothing reached the pushInsteadOf target"
none_ran
t_end

t_begin "the temporary clone is removed, pushed or refused"
setup; sleep 1; mark; in_repo request >/dev/null
t="$(tmpdir)"; ( cd "$repo" && TMPDIR="$t" bash "$P" run --id s1 --foreground >/dev/null )
assert_eq "" "$(ls -A "$t")" "nothing left in TMPDIR after a push"
setup; sleep 1; mark; in_repo request >/dev/null; git -C "$repo" commit -q --allow-empty -m "chore: later [ABC-1]"
t="$(tmpdir)"; ( cd "$repo" && TMPDIR="$t" bash "$P" run --id s1 --foreground >/dev/null )
assert_eq "" "$(ls -A "$t")" "nothing left in TMPDIR after a refusal"
t_end

t_begin "run refuses a request for another sha"
setup; sleep 1; mark; in_repo request >/dev/null
git -C "$repo" commit -q --allow-empty -m "chore: later [ABC-1]"; touch "$repo/.bearing/state/.check-passed"
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no clone:"
assert_eq "" "$(git -C "$remote" branch --list 'feature/*')" "nothing pushed"
assert_eq 0 "$([ -f "$repo/.bearing/state/push-request" ] && echo 1 || echo 0)" "refused request deleted"
t_end

t_begin "run refuses a request naming a protected or non-task branch, before any clone"
for b in main release/v1.2.0 '--upload-pack=touch' feature/x; do
  setup; sleep 1; mark
  printf 'branch=%s\nsha=%s\ntime=t\n' "$b" "$(git -C "$repo" rev-parse HEAD)" > "$repo/.bearing/state/push-request"
  assert_exit 1 in_repo run --id s1 --foreground
  assert_contains "$T_OUT" "no branch:"
  assert_eq "" "$(git -C "$remote" for-each-ref 'refs/heads/feature/*' 'refs/heads/release/*')" "nothing pushed for $b"
done
t_end

t_begin "origin re-pointed at an unlisted URL pushes nothing"
setup; sleep 1; mark; in_repo request >/dev/null
git -C "$repo" remote set-url origin git@git.example.test:other/repo.git
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no opt-in:"
t_end

t_begin "a redirecting setting in the engineer's global git config refuses, naming it"
for kv in "core.sshCommand=ssh -p 2222" "http.proxy=http://p.example.test:3128" "http.curloptResolve=git.example.test:443:203.0.113.9" "http.sslVerify=false" "url.file:///x.pushInsteadOf=file://"; do
  setup; sleep 1; mark; in_repo request >/dev/null
  git config --file "$home/.gitconfig" "${kv%%=*}" "${kv#*=}"
  assert_exit 1 in_repo run --id s1 --foreground
  assert_contains "$T_OUT" "no transport: $(printf '%s' "${kv%%=*}" | tr 'A-Z' 'a-z')"
  rm -f "$home/.gitconfig"
done
t_end

t_begin "run refuses an opt-in written during the session"
setup; mark; sleep 1; printf 'BEARING_AUTO_PUSH="file://%s"\n' "$remote" > "$envf"; in_repo request >/dev/null
assert_exit 1 in_repo run --id s1 --foreground
assert_contains "$T_OUT" "no opt-in-age:"
t_end

t_begin "run without a request pushes nothing"
setup; sleep 1; mark
assert_exit 1 in_repo run --id s1 --foreground
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
- `request)`: `check_conditions`; unmet: print the lines and `push-check: ...`, exit 1. Met: write the three `key=value` lines atomically to `$st/push-request`, print `push: requested <branch> <short sha>`.
- `run)`: `root` is `CLAUDE_PROJECT_DIR`, else the working directory (no `git rev-parse`); parse `--id` and `--foreground`. `home="$(passwd_home)"`. Read the request with `sed -n 's/^branch=//p'` and `sed -n 's/^sha=//p'`; judge `branch` against `$TASK_RE` before the value is used anywhere. Then the conditions in the Interfaces order; `transport_redirect "$entry"` runs inside `$tmp` under `cleanenv`. Unmet: `rm -f "$st/push-request"`, `result "push refused: <first unmet>"`, `log_gate push refused`, exit 1. Not foreground: the `nohup` line, exit 0. Foreground: `rm -f` the request; the clone; `clone` condition (`cleanenv git -C "$tmp/c" rev-parse HEAD` equals `sha=`); the push, stderr appended to `$st/push.log` with any line holding the entry replaced by its key; result line and `log_gate push pushed|failed`.
- `result` writes `$st/push-result` atomically. `log_gate` appends the `gates.log` line in the guard's format (`time<TAB>gate<TAB>outcome<TAB>ms<TAB>label`).
- `status)`: as in Interfaces.

`brg-guard`:
- After the `git|push` row: `brg-push|run|brg-push run (the Stop hook runs it)`. Line 64 comment: append "The one exception: brg-push run, which only the Stop hook calls, under the engineer's BEARING_AUTO_PUSH opt-in; it pushes from a fresh clone and runs no repository code."
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
- `devguide/src/components/Compass.tsx:27`: "135 rules" becomes 136 (R6).

- [ ] **Step 4: Run the tests**

Run: `bash tests/unit/push_run.sh && bash tests/unit/push_check.sh && bash tests/unit/guard_deny_table.sh && bash tests/unit/guard_session_stop.sh && bash tests/unit/guard_latency.sh && make lint-shell lint-portable`
Expected: each ends `0 failed`; `push_run.sh: 13 cases`; `lint-portable` clean.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/bin/brg-push plugins/bearing/bin/brg-guard README.md devguide/src/components/Compass.tsx tests/unit/push_run.sh tests/unit/guard_deny_table.sh
git commit -m "feat(push): the Stop hook pushes a requested branch from a fresh clone to the listed URL; the agent cannot"
```

---

### Task 4: Strip the hook's agent opt-in path, keep the agent tag refusal, move url_key and passwd_home into brg-push

(amended 2026-10-18: clean-clone push) Task 4 was mid-execution: `110eef7`, fix rounds `f5f6f6b` and `ff00a77` put an opt-in path into the repository's hooks. The three security reviews showed that path runs agent-editable code outside the sandbox, so this task now removes it (fix round 3). The opt-in push no longer goes through the repository's hooks at all (Task 3 pushes from a fresh clone with `core.hooksPath=/dev/null`). Kept from the fix rounds: the round-1 C3 rule (an agent push of any non-branch ref fails, so a tag-only agent push no longer exits 0 early), and the entry-format and settings wording, rewritten for push URL entries. The removed `url_key` and `passwd_home` land in `brg-push` in Task 2 and `transport_redirect` in Task 3, copied from `2baa793`; their tests move with them (list below). Task 4 lands before Task 2 (R1), so between the two commits the functions exist only in history.

**Files:**
- Modify: `plugins/bearing/templates/repo/.githooks/lib.sh`, `plugins/bearing/templates/repo/.githooks/pre-push`
- Modify (copy, identical): `plugins/bearing/skills/git-hooks/templates/.githooks/lib.sh`, `.../pre-push`
- Modify: `plugins/bearing/templates/user/bearing.env` (the `BEARING_AUTO_PUSH` block), `docs/INSTALL.md` (the `BEARING_AUTO_PUSH` row)
- Modify: `plugins/bearing/templates/repo/.claude/settings.json` (`_readme` opt-in lines; `permissions.deny`)
- Test: `tests/unit/githooks_pre_push.sh` (rewrite), `tests/unit/push_settings.sh`
- Generated: `devguide/src/data/internals.json`, `site/src/data/handbook.json` (`make docs`, R18)

**Exactly what to remove** (line numbers at `2baa793`, the same in both copies):

`lib.sh`: delete lines 43-185 and the blank line after them, that is the `url_key` comment and function, `BRG_PUSH_PARAMS` and its comment, `transport_redirect`, `passwd_home`, the `auto_push_allowed` comment block (with the limit paragraph), `AUTO_WHY=""` and `auto_push_allowed`. Nothing else in `lib.sh` changed on this branch, so the file is then byte for byte the file at `a36fdcd`: `git diff --exit-code a36fdcd -- plugins/bearing/templates/repo/.githooks/lib.sh plugins/bearing/skills/git-hooks/templates/.githooks/lib.sh` prints nothing.

`pre-push`:
- line 12: `remote="${1:-origin}"; url="${2:-}"` becomes `remote="${1:-origin}"`.
- lines 25-35 (the "Agent contract (brg-push run, Stop hook)" comment) become:
  ```bash
  # A coding agent's push is refused (the confirmation below). The variable is
  # found before the ref loop so that a non-branch ref in an agent's push, a
  # tag above all, fails there instead of passing as "none a branch update".
  # Bearing's opt-in push never comes here: brg-push pushes from a fresh clone.
  ```
- lines 36-39 (the `agent=""` detection loop): kept where they are, above the ref loop.
- lines 40-42 (`auto=0`, the `auto_push_allowed` call, `why=`): deleted.
- line 52: `if [ "$auto" -eq 1 ] || { [ -n "$agent" ] && [ "$PUSH_CONFIRM" != off ]; }; then` becomes `if [ -n "$agent" ] && [ "$PUSH_CONFIRM" != off ]; then` (lines 53-55 unchanged).
- lines 57-60 (the `auto` block refusing `release/*` and deletion): deleted.
- lines 68-71 (the `auto` fast-forward check): deleted.
- lines 90-92 (comment): back to `# Confirmation (lib.sh PUSH_CONFIRM). The engineer pushes; a coding agent` / `# does not.`
- line 95: `agents) [ -z "$agent" ] || hook_fail "a coding agent is pushing ($agent is set); the engineer runs git push" ;;`
- line 97: `[ -z "$agent" ] || hook_fail "a coding agent is pushing ($agent is set); the engineer runs git push"`
- lines 99-101: the `if [ "$auto" -eq 1 ]; then :` arm is deleted; the CI test becomes the `if` again: `if { [ "${CI:-}" = true ] || [ -n "${GITLAB_CI:-}${GITHUB_ACTIONS:-}" ]; } && [ "${BEARING_PUSH_CONFIRMED:-0}" = 1 ]; then`.
- line 112 (`agent push allowed by BEARING_AUTO_PUSH`): deleted.

After the edit, `git diff a36fdcd -- plugins/bearing/templates/repo/.githooks/pre-push` shows only: the agent detection moved above the ref loop (and gone from the confirmation block), its comment, and the non-branch arm's agent refusal.

**Tests that move** (they leave `githooks_pre_push.sh` here and come back where the code went):
- to `tests/unit/push_check.sh` (Task 2): `url_key normalises https, ssh and scp-style URLs the same way`, `url_key keeps a port other than the default`, `url_key refuses http, git, other schemes and helper forms`, `passwd_home ignores HOME`, `a self-supplied BEARING_ENV, XDG_CONFIG_HOME or HOME does not opt in`, `an exported BEARING_AUTO_PUSH does not opt in` (as `an environment variable does not opt in`), `a path-only entry without the host does not match` (as `a host/path entry is not a push URL and does not opt in`), `a repository not listed in the opt-in is refused`, `a listed path on another host is refused (ssh and scp forms)` and `a port other than the listed one is refused; listing the port allows it` (all three as `origin's key not listed in bearing.env` plus the `url_key` cases).
- to `tests/unit/push_run.sh` (Task 3): `origin re-pointed at an unlisted URL is refused`; `core.sshCommand cannot send an allowed push to another host`, `GIT_SSH_COMMAND cannot send an allowed push to another host`, `each transport variable in the environment refuses, naming it`, `a pushInsteadOf redirect of origin is refused, naming the key` (all as `no repository hook, Makefile, git config or exported variable runs at push time`); `each transport setting in git config refuses, naming it` (as `a redirecting setting in the engineer's global git config refuses, naming it`); `a tag is refused even with the opt-in`, `a release branch is refused with the opt-in`, `a protected branch is refused with the opt-in` (as `run refuses a request naming a protected or non-task branch` and the no-tag assertion of the push case); `a forced update is refused with the opt-in` and `a branch deletion is refused with the opt-in` (`run` has no force and no delete form; the push case pins the one command).
- dropped as moot: `a push straight to an unlisted URL is refused`, `another remote name is refused even when its URL is listed`, `a pushurl that differs from the url is refused`, `a remote helper for origin refuses`, `with no transport setting, and with brg-push's pinned -c flags, the push is allowed`, `agent push of a feature branch allowed with the opt-in, gate run`, `a listed host/path is allowed in ssh and scp-style form` (the push never uses origin's url, remote name or pushurl, and never meets the hook).

**Interfaces:**
- Produces: `lib.sh` with no opt-in code (no `auto_push_allowed`, `url_key`, `passwd_home`, `transport_redirect`, `BRG_PUSH_PARAMS`, `AUTO_WHY`).
- Produces: in `pre-push`, with an agent variable set and `PUSH_CONFIRM` not `off`: a non-branch ref fails `hook_fail "an agent push carries only branches: <ref>"`; every other agent push fails `a coding agent is pushing (<VAR> is set); the engineer runs git push`, whatever `bearing.env` holds.
- Produces: `permissions.deny` gains `Edit(~/.gitconfig)` and `Edit(~/.config/git/**)` (the push reads the engineer's global git config).

- [ ] **Step 1: Write the failing test** (replace `tests/unit/githooks_pre_push.sh`)

```bash
#!/usr/bin/env bash
# tests/unit/githooks_pre_push.sh: the committed pre-push hook refuses every
# coding agent's push, a BEARING_AUTO_PUSH entry or not, and refuses an
# agent's tag push even when no branch is pushed; the engineer's push runs
# the gate; the hooks carry no opt-in code (Bearing's opt-in push runs from
# a fresh clone and never meets this hook). bash 3.2 safe.
set -u
. "$(dirname "$0")/../lib/assert.sh"
H="$KIT/plugins/bearing/templates/repo/.githooks"
H2="$KIT/plugins/bearing/skills/git-hooks/templates/.githooks"
unset BEARING_ENV BEARING_AUTO_PUSH
home="$(tmpdir)"; mkdir -p "$home/.config/bearing"; envf="$home/.config/bearing/bearing.env"
setup() {
  repo="$(tmpdir)"; remote="$(tmpdir)/r.git"; git init -q --bare "$remote"
  git -C "$repo" init -q -b main; cp -R "$H" "$repo/.githooks"
  # A passwd home for the fixture: the hooks before this task read the
  # opt-in there; after it nothing reads it, and the entry must not matter.
  printf "passwd_home() { printf '%%s\\\\n' '%s'; }\n" "$home" >> "$repo/.githooks/lib.sh"
  git -C "$repo" config user.email t@example.com; git -C "$repo" config user.name t
  git -C "$repo" config commit.gpgsign false
  printf 'check:\n\t@echo check: passed\n' > "$repo/Makefile"; git -C "$repo" add -A; git -C "$repo" commit -q -m "chore: init"
  git -C "$repo" remote add origin "$remote"; git -C "$repo" push -q origin main 2>/dev/null
  git -C "$repo" config core.hooksPath .githooks
  git -C "$repo" switch -q -c feature/ABC-1-Thing; git -C "$repo" commit -q --allow-empty -m "feat: a [ABC-1]"
  : > "$envf"
}
agent_push() { ( cd "$repo" && CLAUDECODE=1 git push "$@" 2>&1 ) }
landed() { git --git-dir="$remote" for-each-ref --format='%(refname)' 'refs/heads/feature/*' 'refs/tags/*'; }

t_begin "an agent push of a task branch is refused"
setup
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing (CLAUDECODE is set); the engineer runs git push"
assert_eq "" "$(landed)" "nothing landed"
t_end

t_begin "a BEARING_AUTO_PUSH entry does not let an agent push through the hook"
setup
p="${remote%.git}"
printf 'BEARING_AUTO_PUSH="localhost/%s file://%s"\n' "${p#/}" "$remote" > "$envf"
t_run agent_push --no-follow-tags origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "a coding agent is pushing (CLAUDECODE is set); the engineer runs git push"
assert_not_contains "$T_OUT" "auto push"
assert_eq "" "$(landed)" "nothing landed"
t_end

t_begin "an agent tag-only push is refused"
setup; git -C "$repo" tag v1.0.0
t_run agent_push origin v1.0.0
assert_contains "$T_OUT" "an agent push carries only branches: refs/tags/v1.0.0"
assert_eq "" "$(landed)" "nothing landed"
t_end

t_begin "an agent push of a branch and a tag is refused at the tag"
setup; git -C "$repo" tag -a v1.0.1 -m "v1.0.1"   # annotated: --follow-tags sends only those
t_run agent_push --follow-tags origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "an agent push carries only branches: refs/tags/v1.0.1"
assert_eq "" "$(landed)" "nothing landed"
t_end

t_begin "an agent push to main is refused"
setup
t_run agent_push origin HEAD:refs/heads/main
assert_contains "$T_OUT" "direct push to main is not allowed"
t_end

t_begin "with PUSH_CONFIRM=off an agent push goes through as before"
setup; printf "PUSH_CONFIRM='off'\n" >> "$repo/.githooks/lib.sh"
t_run agent_push origin HEAD:refs/heads/feature/ABC-1-Thing
assert_contains "$T_OUT" "gate passed"
assert_eq "refs/heads/feature/ABC-1-Thing" "$(landed)"
t_end

t_begin "the engineer's push of a task branch runs the gate"
setup; printf "PUSH_CONFIRM='agents'\n" >> "$repo/.githooks/lib.sh"
t_run bash -c "cd '$repo' && env -u CLAUDECODE -u CLAUDE_CODE_ENTRYPOINT git push origin HEAD:refs/heads/feature/ABC-1-Thing 2>&1"
assert_contains "$T_OUT" "1 branch ref(s), 1 commit message(s) checked, gate passed"
t_end

t_begin "the hooks carry no opt-in code"
n=0
for f in "$H/lib.sh" "$H/pre-push" "$H2/lib.sh" "$H2/pre-push"; do
  n=$((n+1))
  assert_eq "" "$(grep -nE 'auto_push_allowed|url_key|passwd_home|transport_redirect|BRG_PUSH_PARAMS|AUTO_WHY|BEARING_AUTO_PUSH' "$f")" "$f"
done
assert_eq 4 "$n" "four hook files checked"
t_end

t_begin "the two copies of the hooks are identical"
assert_exit 0 diff -rq "$H" "$H2"
t_end

t_summary
```

`push_settings.sh`: the header comment says the settings deny edits to `~/.config/bearing`, `~/.gitconfig` and `~/.config/git`; case 1 adds `assert_contains "$deny" "Edit(~/.gitconfig)"` and `assert_contains "$deny" "Edit(~/.config/git/**)"`; case 2 replaces `assert_contains "$readme" "<host>/<path>"` with `assert_contains "$readme" "push URL"` and `assert_contains "$readme" "fresh clone"`, and adds `assert_not_contains "$readme" "pre-push hook's to judge"`.

- [ ] **Step 2: Run them to see them fail**

Run: `bash tests/unit/githooks_pre_push.sh; bash tests/unit/push_settings.sh`
Expected: `githooks_pre_push.sh: 9 cases, <m> assertions, <k> failed` with FAIL on `a BEARING_AUTO_PUSH entry does not let an agent push through the hook` (the committed hook allows it: `agent push allowed by BEARING_AUTO_PUSH`) and on `the hooks carry no opt-in code`; the other seven pass on the committed hooks. `push_settings.sh` FAILs on the two changed cases.

- [ ] **Step 3: Implement**

Apply the removal list above to `plugins/bearing/templates/repo/.githooks/{lib.sh,pre-push}` and copy both files to `plugins/bearing/skills/git-hooks/templates/.githooks/`.

`plugins/bearing/templates/user/bearing.env`: replace the `BEARING_AUTO_PUSH` block with:

```
# Optional: the repositories where Bearing may push the current task
# branch for you, after make check passed and only when merge-request or
# autopilot asked for it. Default: none, Bearing never pushes. Each entry is
# the full push url of one repository, ssh://, scp-style (git@host:path) or
# https://, separated by spaces or commas, with no # inside (a # starts a
# comment). Bearing pushes to the entry whose host and path match origin's
# url (scheme, user and .git do not count; a port other than ssh 22 or
# https 443 does), never to origin's configured url. http://, git:// and
# helper urls never count. The push runs from a fresh clone of the branch
# with a cleared environment (PATH=/usr/bin:/bin, your ssh agent), so no
# hook, Makefile or git setting of the repository takes part; an ssh
# command, proxy or insteadOf rewrite of the entry in your global git config
# stops it, naming the key. Prefer ssh with an agent: an https entry needs a
# credential helper git finds on that PATH. Never main, master, develop or
# release branches, never a tag, never a force push, never a merge. Read
# from this file, in your home directory as the passwd entry names it
# (BEARING_ENV and XDG_CONFIG_HOME do not move it for this key); set it here
# by hand (brg-config refuses it), before the session that uses it starts.
# This is the one key an environment variable does not override.
# BEARING_AUTO_PUSH="git@git.example.com:Shop/Server/ShopApi.git ssh://git@git.example.com:2222/Shop/Client/ShopWeb.git"
```

`docs/INSTALL.md`, the `BEARING_AUTO_PUSH` row: `| \`BEARING_AUTO_PUSH\` | full push urls (\`git@host:group/repo.git\`, \`ssh://git@host:2222/group/repo.git\`, \`https://host/group/repo.git\`; http://, git:// and helper urls never count) of the repositories where merge-request and autopilot may have the current task branch pushed after the gate; Bearing pushes from a fresh clone to the entry whose host and path match origin's url, never to origin's configured url; read from \`~/.config/bearing/bearing.env\` under the passwd home only, never from the environment, \`BEARING_ENV\` or \`XDG_CONFIG_HOME\` | empty (Bearing never pushes) |`.

`settings.json`: add `Edit(~/.gitconfig)` and `Edit(~/.config/git/**)` after `Edit(~/.config/bearing/**)` in `permissions.deny`. In `_readme`, the lines from `"Opt-in: a <host>/<path> entry in BEARING_AUTO_PUSH in the engineer's",` through `"hook's to judge (.githooks/pre-push); the agent never merges, tags or deploys.",` become:

```
    "Opt-in: a push URL in BEARING_AUTO_PUSH in the engineer's personal",
    "bearing.env (~/.config/bearing; an exported variable is never read, and",
    "Edit and Bash are denied that directory), chosen by matching origin's",
    "host and path. brg-push run pushes from a fresh clone of the task branch",
    "with a cleared environment, so no repository hook, Makefile or git setting",
    "runs outside the sandbox; the pre-push hook still refuses every agent push.",
    "Edit is denied ~/.gitconfig and ~/.config/git too: the push reads them.",
    "The agent never merges, tags or deploys.",
```

Then `make docs` (the test counts in the generated data change).

- [ ] **Step 4: Run the tests and the gate parts**

Run: `bash tests/unit/githooks_pre_push.sh && bash tests/unit/githooks_install.sh && bash tests/unit/githooks_pre_commit.sh && bash tests/unit/push_settings.sh && bash tests/unit/config_helper.sh && git diff --exit-code a36fdcd -- plugins/bearing/templates/repo/.githooks/lib.sh plugins/bearing/skills/git-hooks/templates/.githooks/lib.sh && make lint-shell lint-portable lint-prose lint-json lint-skills lint-docs lint-budget`
Expected: `githooks_pre_push.sh: 9 cases, <m> assertions, 0 failed`; `githooks_install.sh`, `githooks_pre_commit.sh`, `push_settings.sh` (3 cases), `config_helper.sh` each `0 failed`; the `git diff` prints nothing; `lint-docs: 5 generated docs up to date`; the other lints clean.

- [ ] **Step 5: Commit**

```bash
git add plugins/bearing/templates/repo/.githooks plugins/bearing/skills/git-hooks/templates/.githooks plugins/bearing/templates/user/bearing.env docs/INSTALL.md plugins/bearing/templates/repo/.claude/settings.json tests/unit/githooks_pre_push.sh tests/unit/push_settings.sh devguide/src/data/internals.json site/src/data/handbook.json
git commit -m "fix(githooks): drop the hook's agent opt-in path; an agent push or tag through the hook is refused"
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
- Consumes: `brg-push check|request|status` (Tasks 2, 3); `.bearing/state/push-result` line `pushed <branch> <sha> to <key> <time>` (amended 2026-10-18: clean-clone push: the key of the listed entry, not `origin`).
- Produces: `g_mr` passes when the upstream sha equals HEAD and `push-result` records that sha; note `; upstream <ref> pushed by brg-push at <short sha>`. (amended 2026-10-18: clean-clone push) The push from a clone sets no upstream and does not move the working repository's `origin/<branch>`, so this path fires only after the engineer fetches (R16: it rarely fires); keep it, and say so in the code comment.

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
printf 'pushed feature/T-8-x %s to git.example.test/group/shop 2026-10-18T10:00:00Z\n' "$(git -C "$d" rev-parse HEAD)" > "$d/.bearing/state/push-result"
assert_exit 0 ap "done" mr
assert_contains "$T_OUT" "pushed by brg-push"
printf 'pushed feature/T-8-x %s to git.example.test/group/shop 2026-10-18T10:00:00Z\n' "0000000000000000000000000000000000000000" > "$d/.bearing/state/push-result"
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
- `def pushed_by_brg_push(d)`: read `.bearing/state/push-result`; match `^pushed (\S+) ([0-9a-f]{40}) to \S+ ` (amended 2026-10-18: clean-clone push); return the sha or `""`.
- In `g_mr`, before the two refusals: `if upstream and upstream_sha(d) == git(d, "rev-parse", "HEAD") == pushed_by_brg_push(d): note = f"; upstream {upstream} pushed by brg-push at {sha[:8]}"` and skip them.
- Line 9 docstring: "Nothing here pushes, merges or deploys; a push, where the engineer opted the repository in, is brg-push's from the Stop hook."; line 112 gate text: "nothing pushed except by brg-push under the opt-in"; line 959: "changes it. Nothing was merged or deployed; the push is the engineer's, or brg-push's where the repository is opted in."

`merge-request/SKILL.md`:
- description: `'Prepares the merge request for the current branch: gate run, commit audit, diff summary, description, ticket link; pushes only where opted in. Use when asked to "prepare the MR", "write the PR description".'` (at most 220 characters; `make lint-skills` checks).
- line 10: "The engineer pushes and opens the MR in under a minute with what this produces, or, where they opted the repository in, the Stop hook pushes the branch for them."
- step 8, after the description is printed: "Then `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-push" check`. Exit 0: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-push" request` and print `Push: requested; the Stop hook pushes <branch> from a fresh clone to the URL listed for origin when this turn ends and the gate holds (brg-push status shows the result)`. Otherwise print its first `no` line and the push command as below." (amended 2026-10-18: clean-clone push)
- output contract line 123: `Push: requested (opt-in) | yours: git push -u origin <branch>   MR | PR: <url pattern>`.
- gotcha line 128: "Never run `git push`, ... If asked, decline in one line and print the command. The only push path is `brg-push request` after a passing `brg-push check`; the Stop hook makes the push, never this skill."
- `allowed-tools` add `Bash(bash *bin/brg-push check*), Bash(bash *bin/brg-push request*), Bash(bash *bin/brg-push status*)`.

`autopilot/SKILL.md`:
- description: `'Runs unattended from one requirement statement to a prepared merge request, taking each decision as Proposed for review; pushes only where opted in. Use when asked to "autopilot this", "run it end to end" or "build this unattended".'`
- lines 13-15: "The run never merges or deploys, and pushes only through `brg-push` where the engineer opted the repository in: the guard, the sandbox and the pre-push hook stop any other push, and the last stage prints the push command when there is no opt-in." (amended 2026-10-18: clean-clone push: unchanged in substance; the pre-push hook now refuses every agent push, and `brg-push` never passes through it)
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

Keep each sentence short and true for a repository without the opt-in. Examples: `README.md:6` "(the agent never pushes unless you opt a repository in, and then only its feature branch after the gate; every gate prints a count; everything traces)"; `docs/flows.json` bugfix `mr` "why": "It prepares everything and pushes only where you opted the repository in."; feature `mr` "does": "The gate, the commit audit and the filled template; you push, or the Stop hook does where you opted the repository in."; `bin/gen-guide.py:800` "description in .scratch, push command; the engineer pushes, or the Stop hook where the repository opts in"; `Architecture.tsx` WALLS `says` for `guard` and `deny` add "brg-push run is the one exception, and only the Stop hook calls it", `prepush` (amended 2026-10-18: clean-clone push) adds "every agent push and tag, opted in or not; the opt-in push is brg-push's, from a fresh clone that runs no repository hook"; the `207` paragraph adds one sentence on the opt-in: "Where the engineer lists a repository in BEARING_AUTO_PUSH, the Stop hook clones the task branch fresh and pushes it to the listed URL; nothing from the repository runs outside the sandbox." The agents wall (line 50, R6) names the same exception. `start-task:100` "which the engineer runs, or which merge-request requests where the engineer opted the repository in"; `:161` keeps the command and adds "(or merge-request requests it under the opt-in)". `README.md:85` Stop row adds the push; `:120` adds "The one exception is opt-in: list a repository's push URL in `BEARING_AUTO_PUSH` and merge-request can ask the Stop hook to push its feature branch after the gate (`brg-push`, from a fresh clone)." (amended 2026-10-18: clean-clone push); `:237-243` names the key. Then `make docs`.

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

- `merge-request`, `opt-in-push-request`: a fixture repository on `feature/PAY-300-Receipts` with a passing `make check`, `.bearing/state/.push-optin` holding `on` and a local bare `origin`; prompt "Get the MR ready for the receipts branch." Expectations: `brg-push check` ran and printed `push-check: 8 conditions, 8 met`; `brg-push request` ran; no `git push` and no `brg-push run` ran in the transcript; the report's `Push:` line says `requested (opt-in)` and names no URL; the push command is not printed as the engineer's next step. (amended 2026-10-18: clean-clone push: 8 conditions, no `pre-push` line; the eval never runs the Stop hook, so it pushes nothing.)
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

Added: opt-in push (`BEARING_AUTO_PUSH` in `bearing.env`, default empty; `brg-push check|request|status`; the Stop hook pushes the current feature branch after the gate, never main, master, develop, release branches or tags, never forced, never merged); the `site` flow for landing pages and marketing sites (`start-task --flow site`); task sets across repositories (`start-task --repos`, the `## Repos` progress section, `progress.py set`, the merge order, `references/task-set.md`); a definition-of-done item for task sets. Changed: the pre-push hook refuses an agent's tag push even when no branch is pushed (every other agent push it refused already; the opt-in push never passes through it) (amended 2026-10-18: clean-clone push); `brg-config` refuses to set the auto-push key; the settings template denies `Edit(~/.config/bearing/**)` and `brg-push run`; AGENTS.md rule 2 names the exception; merge-request and autopilot descriptions say "pushes only where opted in"; autopilot's `mr` gate accepts a push by `brg-push`. (amended 2026-10-18: clean-clone push) Note for existing repositories: none needed for the opt-in push, which runs no repository hook; list the repository's push URL in `BEARING_AUTO_PUSH`. Security: the push runs from a fresh clone under a cleared environment, so no repository hook, Makefile or git setting runs outside the sandbox; CI checks the pushed branch.

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
