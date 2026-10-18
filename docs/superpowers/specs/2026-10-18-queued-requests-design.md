# Queued requests: opt-in push, a site flow, multi-repo tasks

Status: draft for review, 2026-10-18. Branch `feat/QueuedRequests`, cut
from `main` at `e6d407d` (v0.8.0). Sub-project 5 of the Bearing
improvement programme. Sub-projects 2 (design pipeline), 3 (quality
phases) and 4 (GenAI pack, the `bearing-genai` plugin) merge first; this
branch is rebased on top of them before its plan runs.

The user skipped the brainstorming questions. Every choice below that
is not quoted from the three requests is marked **author's call**.
Repository facts are cited as `path:line` at `e6d407d`.

## Intent

Three requests the tech lead queued, in the order given:

| # | Request (as queued) | Outcome this spec commits to |
|---|---|---|
| 1 | Opt-in auto push from bearing.env; default off; the current feature branch only, never main, master, release branches or tags, never force, never merge, after the gate passes | One personal opt-in key; one executor (`brg-push`) that the Stop hook runs outside the sandbox; the raw `git push` stays blocked everywhere; every "never pushes" claim names the exception |
| 2 | A light workflow for marketing landing pages and websites: no PRD, HLD, LLD or API contract; keeps screen design, accessibility, performance and a review | A sixth flow, `site`, in `docs/flows.json`, eleven steps on its main line, chosen per repository |
| 3 | Simpler, explicit multi-repo and microservices handling: start, track, finish; state files, branch names, one MR per repo, merge order; smallest change to five skills | A "task set": one task id, one branch name in every repository, a `## Repos` section in each repository's progress file, one MR per repository, a declared merge order, and one shared reference the five skills cite |

## Constraints

- No em dashes in any file (`make lint-prose`, `Makefile:147-150`).
- Every gate fails on empty input and prints the count it checked
  (user standing rule; the house pattern is `lint-plugin-size`,
  `bin/lint-plugin-size.py:22-23,51`).
- A skill that asks uses AskUserQuestion in `allowed-tools` and cites
  `${CLAUDE_PLUGIN_ROOT}/references/console.md`
  (`plugins/bearing/references/console.md:14-17`; enforced by
  `lint-questions`, `Makefile:85-96`).
- Shell is bash 3.2 portable: no `sed -i`, `grep -P`, `readlink -f`,
  `date -d`, no `perl` (`make lint-portable`); Python is stdlib only.
- Every SKILL.md stays at 200 lines or fewer (`lint-skill-size`,
  `Makefile:68-83`); detail goes to `references/`.
- Every command a skill body runs is granted in its `allowed-tools`
  (`lint-tools`, `bin/lint-skill-tools.py:1-30`); `Bash(git -C` grants
  are refused outright (`Makefile:49`).
- Files under `plugins/bearing` stay few: the plugin is at 508 files today
  and about 451 after sub-project 4; the limit is under 512
  (`bin/lint-plugin-size.py:14`). This spec adds **2** files there:
  `bin/brg-push` and `references/task-set.md`.
- Commits are Conventional, with no attribution trailer of any kind.
- Bearing itself never pushes, merges or tags this branch; the engineer does.

## Repository facts the design rests on

- There is no per-repository `bearing.env`. The file is personal:
  "Mode 600. Never inside a repository."
  (`plugins/bearing/templates/user/bearing.env:1`). Project answers live
  in the tracked `.bearing/config.json`; personal ones in `bearing.env`
  (`plugins/bearing/bin/brg-config:2-4`).
- Four layers stop a push today, and the devguide says so: AGENTS.md rule 2
  (`plugins/bearing/templates/repo/AGENTS.md:16`), the settings deny
  `Bash(git push:*)` (`plugins/bearing/templates/repo/.claude/settings.json:160`),
  the guard's verb row `git|push` (`plugins/bearing/bin/brg-guard:69`, message
  at `:253`), and the pre-push hook refusing any agent environment
  (`plugins/bearing/templates/repo/.githooks/pre-push:60-82`)
  (`devguide/src/pages/Architecture.tsx:49-53,207`).
- A fifth layer exists: the sandbox. Its network allowlist has no git
  host, so a push from any sandboxed Bash call fails at the network, and
  it denies reads and writes of `~/.config/bearing`
  (`settings.json:361,410-424`). Anything that pushes must therefore run
  outside the sandbox. Hooks do; Bash calls do not.
- The Stop hook can push. (amended 2026-10-18: clean-clone push) Task 0
  was run by the engineer on 2026-10-18 against a local bare remote: the
  Stop hook pushed (`rc=0`), read `~/.config/bearing` and saw the ssh
  agent, while the model's Bash `ls` of `~/.config/bearing` was blocked.
  A network ssh push was not tried (local remote only, by design, R8). An
  untrusted workspace ignores `permissions.allow` but still runs the Stop
  hook. The Stop hook stays the trigger.
- Whatever runs in that hook runs outside the sandbox with the
  engineer's credentials. (amended 2026-10-18: clean-clone push) Three
  security reviews of the first design, a push from the working tree
  through the repository's pre-push hook, showed that such a push runs
  agent-editable code there: the repository's `.githooks` (a two-line
  edit to `lib.sh` sent a push to an attacker's host), the `Makefile`
  through the hook's `make check`, and `.git/config` keys
  (`credential.helper`, `http.curloptResolve` with `http.sslCAInfo`,
  `core.sshCommand`). A deny list in the hook cannot fix this, because
  the agent can rewrite the code that checks it. The design below
  therefore runs no repository code outside the sandbox at all.
- The guard reads `bash <file> args` as `<file> args` and matches the
  basename (`brg-guard:1148-1182`), so a verb row for a kit script blocks
  it however it is called.
- The Stop gate already knows whether `make check` passed after the last
  change and logs `stop-gate passed` (`brg-guard:1645-1672`).
- Autopilot's `mr` gate fails when the branch has an upstream that moved
  during the run (`plugins/bearing/bin/brg-autopilot:796-815`); its report
  says "Nothing was pushed, merged or deployed." (`brg-autopilot:959`).
- Flows are data: `docs/flows.json` (four flows today, five after
  sub-project 4), validated by `bin/gen-guide.py:1273-1340`, rendered by
  the site from `site/src/data/handbook.json`, and compiled into
  `plugins/bearing/bin/flow-steps.tsv` for `brg-session next-step`, which
  picks the flow from the branch type only
  (`plugins/bearing/bin/brg-session:103-110`).
- Multi-repo today: `high-level-design` writes
  `docs/architecture/repo-plan.json` with one entry per repository and a
  `git_path` of `<group>/<Client|Server|Infrastructure>/<name>`
  (`plugins/bearing/skills/high-level-design/references/design-set.md:9-15`,
  template `.../templates/repo-plan.json`); autopilot scaffolds siblings
  beside the run's repository but builds and opens the MR in that one
  repository only (`plugins/bearing/skills/autopilot/references/design-stages.md:31-37`).
  The state file is per branch, per repository and ignored
  (`plugins/bearing/bin/brg-state-path:1-17`); the progress file
  `docs/progress/<ID>.md` is per repository and committed
  (`plugins/bearing/skills/session-handoff/scripts/progress.py:1-34`).

## Design

### A. Opt-in push (request 1)

**The shape in one paragraph.** (amended 2026-10-18: clean-clone push)
The agent asks (`brg-push request`, in the sandbox); the Stop hook
pushes (`brg-push run`, outside it). `run` never pushes from the working
tree. Under a cleared environment it clones the requested branch from
the repository path into a fresh temporary directory, so no repository
hook and no repository config takes part, pushes that clone's branch to
the exact URL the engineer listed in the personal `bearing.env`, and
deletes the clone. It runs no `make`, no hook and no git command inside
the working repository, except the `git upload-pack` the clone starts
there, which git builds to read an untrusted repository safely. The
pre-push hook goes back to refusing every agent push.

**A1. The key.** (amended 2026-10-18: clean-clone push)
`BEARING_AUTO_PUSH` in the personal `bearing.env`. The request says "the
repository's bearing.env"; no such file exists, so the opt-in is
personal (user decision 2026-10-18, R0). Value: a space- or
comma-separated list of full push URLs, each `ssh://`, scp-style
(`git@host:group/repo.git`) or `https://`. The round-2 scheme allow-list
holds: `http://`, `git://`, `git+ssh://`, `ssh+git://`, any other scheme
and a `<helper>::<address>` form never count; an absolute path or a
`file://` URL is accepted as the test form. `brg-push` picks the entry
whose `url_key` equals the `url_key` of origin's url and pushes to that
entry, never to origin's configured url. `url_key` is the round-2
normalisation: `<host>/<path>` with scheme, user and password dropped,
the host lower-cased, leading and trailing slashes and `.git` dropped; a
port other than the scheme's default (ssh 22, https 443) stays in the
key (`host:2222/group/repo`), and a non-numeric port gives no key. A
`<host>/<path>` entry from the first fix round is not a URL and matches
nothing. Empty, unset or `off` is off. No wildcard (anti-goal G1). The
key is read from `<passwd home>/.config/bearing/bearing.env` only, the
home taken from the passwd entry (`passwd_home`: tilde expansion of a
validated `id -un`, the directory owned by the effective user), never
from `BEARING_ENV`, `XDG_CONFIG_HOME`, `HOME` or an exported
`BEARING_AUTO_PUSH` (Task 1 already refuses to set it and ignores the
environment), because the agent controls its own environment.
`brg-push` never prints an entry, only its key: an https entry may carry
a token.

Why personal and not `.bearing/config.json`: the standing rule "I push,
merge, tag and deploy" is the engineer's, and a tracked key would let a
cloned repository turn pushing on for everyone who opens it. A team that
wants it documents the line to add in its CONTRIBUTING.md (open
question Q1 offers the two-key variant).

**A2. Nobody but the engineer writes it.** `brg-config set` refuses any
key that maps to `BEARING_AUTO_PUSH` (`auto-push`, `auto_push`,
`AUTO.PUSH`; the mapping is at `brg-config:9`) with exit 2 and
"set BEARING_AUTO_PUSH by hand in bearing.env". The settings template
adds `Edit(~/.config/bearing/**)` to `permissions.deny`, so Edit and
Write cannot reach the file even under autopilot's `--allowedTools Write`
(`brg-autopilot:1252`); the sandbox already denies Bash writes there
(`settings.json:420-422`). As a last line, `brg-push run` refuses when
`bearing.env` is newer than the session's start mark
(`.bearing/state/.session-<id>`, written at `brg-guard:1570-1574`): an
opt-in must predate the session that uses it. (amended 2026-10-18:
clean-clone push) The push reads the engineer's global git config and
ssh config, so the template also denies `Edit(~/.gitconfig)` and
`Edit(~/.config/git/**)`; the sandbox already denies Bash writes to
`~/.gitconfig` and `~/.ssh`.

**A3. One executor, `plugins/bearing/bin/brg-push`.** (amended
2026-10-18: clean-clone push) Bash 3.2, about 260 lines, the only new
script. Plugin-owned: it lives in the plugin, outside every repository,
so the agent cannot edit the code that decides the destination. It
holds the code that the first design put in the repository's `lib.sh`:
`url_key`, `passwd_home` and the round-2 transport check. Subcommands:

```
brg-push check            the conditions below, one line each, then
                          "push-check: 8 conditions, M met"; exit 0 all met,
                          1 any unmet, 2 usage or not a git repository
brg-push request          check; when it exits 0, write
                          .bearing/state/push-request (branch, HEAD sha, time)
brg-push run --id <sid>   Stop hook only: the run conditions; then, in the
                          background, clone the branch fresh and push it
brg-push status           the last result line, or "push: none"
brg-push optin-record     SessionStart only: write .bearing/state/.push-optin
                          (on|off) for this repository from bearing.env
```

Where each subcommand runs. `check`, `request` and `status` run in the
agent's Bash, inside the sandbox, where any git command is harmless.
`optin-record` and `run` run from hooks, outside the sandbox, and there
they run no git command inside the working repository and nothing from
it: origin's url is read as text with
`git config --file <git common dir>/config --get remote.origin.url`
(includes not followed; the git directory found by reading `.git`, a
directory, or a `gitdir:` file plus its `commondir`), and the branch
content is reached only through `git clone --no-local`, whose source
side is `git upload-pack`, the one git command git documents as safe to
run in an untrusted repository (settings that run a program, such as
`uploadpack.packObjectsHook`, are honoured from protected config only).
No `git status`, `git diff`, `make` or repository hook runs from
`optin-record` or `run`.

`check` conditions, each printed as `ok <name>: <detail>` or
`no <name>: <detail>`. They are advisory: they tell the agent and the
engineer whether a request can succeed, and `run` re-judges what matters.

1. `opt-in`: `.bearing/state/.push-optin` reads `on`. `optin-record`
   writes it at session start, outside the sandbox, because the sandbox
   hides `bearing.env` from Bash: `on` when an entry's `url_key` equals
   the `url_key` of origin's url.
2. `origin`: a remote named `origin` exists and its url has a `url_key`
   (the detail prints the key).
3. `branch`: on a branch (not detached) matching
   `^(feature|bugfix|hotfix|chore|docs)/[A-Z][A-Z0-9]*(-[0-9]+)+-[A-Za-z0-9]+$`
   (`plugins/bearing/skills/merge-request/SKILL.md:56`).
4. `not-protected`: not `main`, `master`, `develop`, not `release/*`,
   and not in `PROTECTED_BRANCHES` of `.githooks/lib.sh` when present
   (`templates/repo/.githooks/lib.sh:12`). `hotfix/*` is allowed (user
   decision 2026-10-18, R0).
5. `clean`: `git status --porcelain --untracked-files=no` is empty.
   (Task 3 fix round 1) An uncommitted `docs/progress/<ID>.md` of the
   current task and paths under `.scratch/` (untracked, or changed in the
   work tree only) do not count here or in `gate`: merge-request writes
   them after `make check` and the push sends committed history only. A
   committed change to them still counts (by its commit time).
6. `ahead`: at least one commit on the branch not on the base
   (`origin/develop`, else `origin/main`, else `origin/master`).
7. `gate`: `.bearing/state/.check-passed` exists and no file in the
   branch diff (`git diff -z --name-only <base>...HEAD`) or the working
   tree (`git status -z`) is newer than it, paths under
   `.bearing/state/` skipped (R3 as narrowed by Task 2 fix round 1: a
   tracked `.bearing/` file changed after `make check` counts); `-z` so a name with a space or a non-ASCII byte is
   counted, not dropped. The line prints how many files it compared;
   zero files compared is `no gate: 0 files on the branch`.
8. `fast-forward`: `origin/<branch>` absent, or an ancestor of HEAD
   (local ref only). There is no force option at all; the remote refuses
   a non-fast-forward of an unforced push in any case.

The first design's condition 9 (`pre-push`: the repository's hooks know
the opt-in) is gone: no repository hook takes part in the push.

`run` conditions, the same line format, then
`push-run: 8 conditions, M met`:

1. `request`: `.bearing/state/push-request` holds `branch=` and a
   40-hex `sha=` (absent prints `no request: none`).
2. `branch`: the request's branch matches the task-branch regex above.
   The value comes from an agent-writable file, so it is judged before it
   reaches any command line, which also rules out an option-shaped name.
3. `not-protected`: the request's branch is not `main`, `master`,
   `develop` or `release/*`, nor in `PROTECTED_BRANCHES` read as text
   with `sed` from the repository's `lib.sh` (never sourced).
4. `opt-in`: an entry of `BEARING_AUTO_PUSH` in the passwd-home
   `bearing.env` has the `url_key` of origin's url; the detail prints the
   key, never the entry.
5. `opt-in-age`: `bearing.env` is not newer than the session mark.
6. `marker`: `.bearing/state/.check-passed` exists. Its freshness was
   judged by `request` in the sandbox (condition 7 of `check`) and the
   Stop gate calls `run` only on `passed`; `run` does not re-read the
   working tree to judge it (that read would run repository config
   outside the sandbox).
7. `transport`: the round-2 check, applied to the engineer's system and
   global git config read in an empty directory under the cleared
   environment: refused, naming the key, when `core.sshCommand` is set
   to anything but `ssh`, or `core.gitProxy`, `http.proxy`,
   `https.proxy`, `http.<url>.proxy` or `http.curloptResolve` is set, or
   `http.sslVerify` (or `http.<url>.sslVerify`) is false, or a
   `url.<base>.insteadOf` or `pushInsteadOf` value is a prefix of the
   chosen entry, or (Task 3 fix round 1) any `remote.<entry URL>.*` key
   (`pushurl`, `url`, `receivepack` ...), named as `remote.<entry>.<key>`.
   Environment variables need no check: the environment is cleared.
8. `clone`: the clone succeeded and its `HEAD` is the request's `sha`
   (a commit made after the request refuses; the agent requests again).

Besides the `git config --file` reads and a `rev-parse HEAD` inside the
clone, the clone and the push are the only git commands `run` runs. Every
one of them runs under
`env -i PATH=/usr/bin:/bin HOME=<passwd home> SSH_AUTH_SOCK=<value> GIT_TERMINAL_PROMPT=0`,
and the clone and the push also pin `-c core.hooksPath=/dev/null` and run
with `GIT_CONFIG_NOSYSTEM=1` and `GIT_CONFIG_GLOBAL=<tmp>/global`
(Task 3 fix round 1), a config `run` generates holding only the
`credential.*` keys of the engineer's global config, so no `remote.*`,
`url.*`, `push.*` or transport key from any file reaches them; a git that
reports a setting from any other file is refused:

```
git -c core.hooksPath=/dev/null clone --no-local --single-branch \
    --branch <branch> --no-tags --no-checkout -- <repository path> <tmp>/c
git -C <tmp>/c -c core.hooksPath=/dev/null push --no-follow-tags \
    <entry URL> HEAD:refs/heads/<branch>
```

`--no-checkout` is added to the decided form: the push needs no work
tree, and without a checkout no attribute or filter of the branch's own
tree takes part. `core.hooksPath=/dev/null` keeps any hook out of the
clone and the push, the engineer's global hooks included, so even a
global config that pointed hooks at the repository would run nothing.
No `--force`, `--force-with-lease`, `--tags`, `--all`, `--mirror`,
`--delete`, `--set-upstream`, no second refspec, never origin's
configured url. A tag is never pushed: the clone has none (`--no-tags`)
and the refspec names one branch. The temporary directory is made with
`mktemp -d` inside `<passwd home>/.config/bearing/tmp` (created mode 700;
the sandbox denies the agent reads and writes there), never `TMPDIR`, and
removed by an `EXIT` trap, pushed or not. Just before the push the
clone's `.git/config` is re-read (includes not followed) and the push is
refused if it holds any key but those git clone writes:
`core.repositoryformatversion`, `core.filemode`, `core.bare`,
`core.logallrefupdates`, `core.ignorecase`, `core.precomposeunicode`,
`core.symlinks`, `extensions.objectformat`, `extensions.refstorage`,
`remote.origin.url`, `remote.origin.fetch`, `remote.origin.tagopt`,
`branch.<branch>.remote`, `branch.<branch>.merge`. (Task 3) The
transport check runs a second time inside the fresh clone, as part of
condition 8, so an `includeIf` of the global config that applies only in
a repository (`gitdir:`, `onbranch:`) is judged too. Every file `run` reads
or writes in `.bearing/state` goes through `state_read` or `state_write`:
the directory is entered one name at a time and judged with getcwd, a
read or an append opens with `O_NOFOLLOW` and `O_NONBLOCK` (python3 -I)
and takes only a regular file with one link, and a whole write is a new
file renamed into place, so a link, a hard link or a FIFO the agent
plants is never followed, read back or waited on. A `.git` file
(`gitdir:`) can point the origin read and the clone source at another
repository; the push still goes only to a URL the engineer listed for
that origin (accepted, amendment ruling Q4). Every hook sets
`core.fsmonitor=false` for each git it starts (ruling Q3), since a
`core.fsmonitor` in `.git/config` names a program git runs when it reads
the index, and (Task 3 fix round 1) `core.hooksPath=/dev/null`, since
`git status` runs a repository's `post-index-change` hook when it
refreshes the index.

`run` checks conditions 1 to 7 at the Stop and prints
`push-run: 7 conditions before the clone, M met`; when all hold it
detaches (`nohup ... &`, R7) so the Stop hook returns inside its 15 s
timeout (`plugins/bearing/hooks/hooks.json`), and the detached
`run --foreground` judges all eight again and pushes. It writes
`.bearing/state/push.log` and one line to `.bearing/state/push-result`
(`pushed <branch> <sha> to <key> <time>` or `push failed: <reason>` or
`push refused: <first unmet>`), and logs gate `push` with outcome
`pushed|refused|failed` through the same `gates.log` format
(`brg-guard:262-297`). Every refusal deletes the request, so a stale
request never fires later. The push does not touch the working
repository: no upstream is set and its `origin/<branch>` moves at the
engineer's next fetch.

**Accepted risk.** (amended 2026-10-18: clean-clone push) No repository
code runs outside the sandbox, so `make check` is not rerun at push
time: `run` trusts the gate marker the sandboxed session wrote, and CI
checks the branch after the push. An agent can forge the marker (touch
`.check-passed`), so an unchecked task branch can reach the remote,
where CI and the merge request review catch it. Nothing else follows
from a forged marker: the branch name, the protected names, the
destination and the transport are judged by plugin code from files the
agent cannot write.

**A4. Where the guard checks it.** Three places in `brg-guard`, no new
hook script:

- `command`: the verb row `git|push` (`brg-guard:69`) and its message
  (`:253`) are unchanged; a raw push stays blocked in every repository,
  opted in or not. One new row, `brg-push|run|brg-push run (the Stop hook
  runs it)`, so the agent can check and request but never execute.
- `stop-gate`: on the `passed` branch (`brg-guard:1672`), when
  `.bearing/state/push-request` exists and `brg-push` sits beside the
  guard, run `brg-push run --id <sid>`; its output is one line. A
  blocked or reminded stop never pushes, which is how "after the gate
  passes" is enforced.
- `session` and `task-id`: `session` calls `brg-push optin-record` on
  startup and resume, and both print an unseen `push-result` once
  (`bearing push: pushed feature/X abc1234 to <key>`), then mark it
  seen. That is how the model, and so the engineer, learns the outcome.
  (amended 2026-10-18: clean-clone push: the line names the entry's key,
  not origin.)

`brg-harness` does not vendor `brg-push` (`brg-harness:160-164` vendors
the session scripts only), and `stop-gate` skips the push when the file
is absent, so other harnesses keep today's behaviour (anti-goal G4).

**A5. The pre-push hook refuses every agent push.** (amended 2026-10-18:
clean-clone push) The hook drops the agent opt-in path entirely: every
agent push through it is refused as before sub-project 5. Both copies
(`plugins/bearing/templates/repo/.githooks/` and
`plugins/bearing/skills/git-hooks/templates/.githooks/`, kept identical
by `Makefile:59`) change as follows.

- `lib.sh` loses every line the branch added (`url_key`,
  `BRG_PUSH_PARAMS`, `transport_redirect`, `passwd_home`, `AUTO_WHY`,
  `auto_push_allowed`) and is again byte for byte the file at the
  branch's start (`a36fdcd`).
- `pre-push` keeps one rule from the first security round (C3): the
  agent detection sits above the ref loop, and in the non-branch arm a
  push of any non-branch ref with an agent variable set and
  `PUSH_CONFIRM` not `off` fails with
  `an agent push carries only branches: <ref>`, so a tag-only agent push
  no longer slips through the early "none a branch update" exit. Every
  other agent push fails at the `PUSH_CONFIRM` step with today's message
  `a coding agent is pushing (<VAR> is set); the engineer runs git push`,
  with or without a `BEARING_AUTO_PUSH` entry.

The opt-in push never meets this hook: the fresh clone has no repository
hooks and `run` pins `core.hooksPath=/dev/null`. So a repository's hook
version no longer matters to auto push, and the first design's "older
hooks refuse" path is gone. The url and home code moved to `brg-push`
(A3), with its tests: the `url_key`, `passwd_home` and self-supplied
`BEARING_ENV`/`XDG_CONFIG_HOME`/`HOME` cases go to
`tests/unit/push_check.sh`, the destination and transport cases to
`tests/unit/push_run.sh`. The round-2 findings about the hook's own deny
list are moot. The guard rows and the settings deny stay as defence in
depth.

**A6. How merge-request uses it.** (amended 2026-10-18: clean-clone
push) Step 8
(`merge-request/SKILL.md:93-98`) gains: run `brg-push check`; when it
exits 0, run `brg-push request` and print
`Push: requested; the Stop hook pushes <branch> from a fresh clone to the URL listed for origin when this turn ends and the gate holds (brg-push status shows the result)`;
otherwise print the unmet conditions in one line and the push command as
today. The MR or PR itself is never created (forge writes stay blocked,
anti-goal G2). The output contract's `Push:` line
(`merge-request/SKILL.md:123`) becomes
`Push: requested (opt-in) | yours: git push -u origin <branch>`. The
gotcha at `merge-request/SKILL.md:128` keeps "never run `git push`" and
adds that `brg-push request` is the only push path. Grants:
`Bash(bash *bin/brg-push check*)`, `Bash(bash *bin/brg-push request*)`,
`Bash(bash *bin/brg-push status*)`.

**A7. How autopilot uses it.** Step 10 (`autopilot/SKILL.md:74-78`) and
`references/review-smoke-and-mr.md:28`: after the report commit (the
last write), run `brg-push check`, then `brg-push request` when it
passes; the run's final Stop pushes. The output contract line
`Push (yours): ...` (`autopilot/SKILL.md:93`) becomes
`Push: requested (opt-in) | yours: git push -u origin <branch>`.
`brg-autopilot`:
- `g_mr` (`brg-autopilot:796-815`) also passes when the upstream's sha
  equals HEAD and `.bearing/state/push-result` records that sha as
  pushed by `brg-push`; any other upstream movement still fails with
  "the run must not push". (amended 2026-10-18: clean-clone push) The
  result line reads `pushed <branch> <sha> to <key> <time>`, so the
  match is on `^pushed (\S+) ([0-9a-f]{40}) to `. The push from a clone
  sets no upstream and does not move the working repository's
  `origin/<branch>`, so this path fires only after a fetch (R16: it
  rarely fires).
- the `mr` stage text (`:112`) reads "nothing pushed except by brg-push
  under the opt-in".
- the report sentence (`:959`) reads "Nothing was merged or deployed;
  the push is <requested under BEARING_AUTO_PUSH | the engineer's>."
The launcher (`brg-autopilot launch`) does not push; the child
session's Stop hook does (one executor).

**A8. Every "never pushes" claim and its change.** Raw `git push` by the
agent stays forbidden everywhere; each claim gains the one exception, or
stays because it describes that raw push.

| Where | Today | Change |
|---|---|---|
| `README.md:6` | "the agent never pushes" | "the agent never pushes except, where you opt a repository in, its feature branch after the gate" |
| `README.md:85` (Stop row) | stop gate only | adds "then, when merge-request requested it and the repository is opted in, `brg-push run`" |
| `README.md:120` | "The engineer runs these" | adds one sentence: the opt-in exception and `BEARING_AUTO_PUSH` |
| `README.md:237-243` Configuration | keys | names `BEARING_AUTO_PUSH` |
| `docs/INSTALL.md:101-115` key table | 13 keys | adds the `BEARING_AUTO_PUSH` row, default empty (off) |
| `plugins/bearing/templates/user/bearing.env` | no key | a commented `# BEARING_AUTO_PUSH=` block with the rules |
| `CONTRIBUTING.md:120` | "A skill never pushes" | "A skill never pushes, except merge-request and autopilot through `brg-push request` under the opt-in" |
| `plugins/bearing/templates/repo/AGENTS.md:16` rule 2 | never push | adds "except a `brg-push request` where the engineer opted this repository in" (budget 3,600 bytes, file is 2,864: `Makefile:157`) |
| `plugins/bearing/templates/repo/.claude/settings.json:10,16` `_readme` | "push ... stay blocked" | names the hook-run exception and the clean-clone push; deny list unchanged plus `Edit(~/.config/bearing/**)`, `Edit(~/.gitconfig)`, `Edit(~/.config/git/**)` (amended 2026-10-18: clean-clone push) |
| `plugins/bearing/hooks/hooks.json:2` | "the agent does not" | adds "except an opted-in feature branch push from the Stop hook" |
| `plugins/bearing/bin/brg-guard:64` comment | engineer pushes | adds the `brg-push` exception; the deny message at `:253` is unchanged (it answers a raw push, pinned by `tests/unit/guard_deny_table.sh:474`) |
| `.githooks/pre-push:60,68,70` (both copies) | agents refused | unchanged in effect: every agent push refused, plus the agent tag refusal (A5) (amended 2026-10-18: clean-clone push) |
| `plugins/bearing/skills/merge-request/SKILL.md:3,10,93-98,123,128` | "never pushes" | A6; the description ends "pushes only where opted in" within 220 chars |
| `plugins/bearing/skills/autopilot/SKILL.md:3,13-15,74-81,93` | "never pushes" | A7, same description pattern |
| `plugins/bearing/skills/autopilot/references/review-smoke-and-mr.md:28` | push command | A7 |
| `plugins/bearing/skills/start-task/SKILL.md:100,161` | "which the engineer runs" | "which the engineer runs, or merge-request requests under the opt-in" |
| `plugins/bearing/bin/brg-autopilot:9,112,959` | nothing pushed | A7 |
| `bin/gen-guide.py:800` | "the engineer pushes" | "the engineer pushes, or the Stop hook where the repository opts in" |
| `docs/flows.json:509,893` (`mr` steps) | "never pushes", "the engineer pushes" | the same qualifier |
| `docs/WORKFLOW.md:232,243` (hand-written) | never pushes | qualifier; lines 157 and 187 are generated and follow `gen-guide.py` |
| `devguide/src/pages/Architecture.tsx:49-53,207` | four walls | each wall's text names how the opt-in passes it (only the Stop hook's `brg-push` passes the guard and the deny; the pre-push hook still refuses every agent push, and the push from a fresh clone never runs it) (amended 2026-10-18: clean-clone push) |
| `devguide/src/pages/Autopilot.tsx:165`, `Start.tsx:133`, `Home.tsx:28` | never pushes | qualifier |
| `site/src/pages/Guides.tsx:167,443` | never pushes | qualifier |
| `plugins/bearing/bin/brg-harness:360,381,502,584` | never push (other harnesses) | unchanged: no auto push off Claude Code (G4) |
| `devguide/src/data/recordings.json`, `devguide/src/components/GuardAnatomy.tsx:26,40`, `devguide/src/pages/Session.tsx:108` | the raw-push deny message | unchanged: still true |
| `devguide/src/pages/Change.tsx:278` | the kit's own repository | unchanged: this repository has no opt-in |
| `evals/*` fixtures and expectations | nothing pushed | unchanged: evals run without the opt-in, so they stay true |
| `docs/SKILLS.md`, `site/src/data/handbook.json`, `devguide/src/data/internals.json` | generated | regenerated by `make docs` |

### B. The site flow (request 2)

A sixth entry in `docs/flows.json` (fifth before sub-project 4),
id `site`, title "Marketing site or landing page", tagline "From a goal
and a page brief to a fast, accessible page, reviewed and shipped.",
when "A landing page, a marketing site or a docs-style site: content and
screens, no product backend, no API to design."

Steps (**author's call** for every step and skill; each step carries
`id`, `title`, `skill`, `pack`, `does`, `output`, `why` per
`gen-guide.py:1301-1305`, no ranking words per `:1294,1311-1313`):

```
phase Frame
step s-task      start-task                   bearing
step s-brief     brainstorming                Superpowers   goal, audience, one primary action, sections, copy source
branch "Is there a repository for the site yet?"
  No:  step s-repo new-repo                   bearing       nextjs stack (react-web for a single static page)
  Yes: []
phase Design
step s-direction design-directions            bearing       (sub-project 2 runs one impeccable round inside it)
branch "Does the site follow an existing design system?"
  No:  step s-system design-system            bearing
  Yes: []
step s-screens   screen-design                bearing       every section and state at 375, 768, 1440
phase Build
step s-build     nextjs                       bearing-apps  the screens as components, static by default
branch "Does the page track visitors or collect a form?"
  Yes: step s-events  analytics-events        bearing
       step s-privacy privacy-review          bearing
  No:  []
phase Check
step s-a11y      accessibility                bearing       WCAG 2.2 AA, axe in Playwright
step s-perf      performance                  bearing       Lighthouse before and after
step s-critique  design-critique              bearing
step s-review    branch-review                bearing
phase Ship
step s-dod       definition-of-done           bearing
step s-mr        merge-request                bearing
step s-verify    verify-deploy                bearing       optional: after the engineer deploys, smoke the pages
```

Eleven steps on the main line against about thirty in greenfield; no
`prd`, `backlog`, `high-level-design`, `low-level-design`,
`openapi-spec`, `data-model` or `threat-model` step. The skills named
all exist today (`ls plugins/bearing/skills`, `plugins/bearing-apps/skills/nextjs`)
or are known (`brainstorming` in `docs/known-skills.txt`), so
`gen-guide.py` validates the flow without new skills.

Choosing the flow. `brg-session next-step` picks the flow from the
branch type only (`brg-session:105`). **Author's call**: a repository is
a site repository for its whole life, so the choice is a project answer:
`.bearing/config.json` key `flow` = `site`, written by `start-task` when
the user picks it (new optional `--flow site`, or the request names a
landing page or marketing site and the user confirms with
AskUserQuestion), read by `next-step` before the branch-type rule (a
`bugfix/` branch still follows `bugfix`). The `workflow` skill's stage
table (`workflow/SKILL.md:46-61`) gains a row "Site | the site flow:
`start-task --flow site`".

Site code changes: the colour maps keyed by flow id
(`site/src/pages/Home.tsx:5`, `site/src/lib/nav.ts:7`) gain
`site: "var(--gs)"` (**author's call**: reuse an existing token, as
sub-project 4 does for `genai`). The count of flows in prose
(`docs/flows.json:2` `_about`, `README.md:215,221`, `docs/INSTALL.md:306`,
`bin/gen-guide.py:9`) is updated to the count after rebase.

### C. Multi-repo tasks (request 3)

**C1. The model, a task set.** One task id, N repositories. Each
repository gets the same branch name `<type>/<ID>-<PascalName>`, its own
ignored state file, its own committed `docs/progress/<ID>.md`, its own
gate run, its own MR. Nothing new is shared on disk across repositories;
what links them is the id in the branch name (already what the
UserPromptSubmit hook and `pre-push` read, `brg-guard` `task-id`,
`.githooks/lib.sh:33-38`) and a `## Repos` section that is identical in
every member's progress file.

**Author's call: one session per repository.** The sandbox lets a Bash
call write only inside the working repository (`settings.json:361`), and
`lint-skills` refuses `Bash(git -C` grants (`Makefile:49`), so a skill
cannot create branches or commit in a sibling. Work moves between
repositories by opening a session in each; the set makes that explicit
instead of fighting the sandbox (Q4).

**C2. The `## Repos` section.** Added to
`plugins/bearing/skills/session-handoff/templates/progress.md` as an
optional list, written by `progress.py write --repo "<n>. <Name> (<path>)"`
(repeatable; replaces the list; `none` clears it). `<n>` is the merge
order, `<path>` is relative to the repository (`../ShopApi`). `check`
validates the items (numbers 1..N, unique, names
`[A-Za-z0-9._-]+`). The file still has to stay under 40 lines
(`progress.py:81`); a set of up to eight repositories fits
(**author's call**: more than eight is refused with that reason).

**C3. `progress.py set`.** New read-only subcommand: for each repository
in this repository's `## Repos` section, at its path, with
`git --no-optional-locks` so a read-only sibling never takes the index
lock: present or missing, the branch present, unpushed commits
(`git log <branch> --not --remotes`), uncommitted files, the gate (the
same rule as condition 7 in A3), and the sibling's own progress
`Status`. Each row ends `ready`, `merged` (its Status is merged) or
`not ready: <first reason>`. Last line:
`set: N repos, R ready, M merged, K not ready; merge order A, B, C`.
Exit 1 with zero repositories listed, with no progress file, or with a
missing repository path; 0 otherwise.

**C4. Merge order.** **Author's call**: providers before consumers.
Default from the repo plan's `git_path` group: `Infrastructure`, then
`Server`, then `Client`, then anything else, ties in plan order; without
a plan, the order given to `start-task --repos`. The user confirms it
once with AskUserQuestion. The rule each MR must meet: merged alone, in
that order, it leaves its default branch working (expand, then
contract). A change that cannot merge alone (a breaking API change both
sides need at once) is named under Risk with the two ways out the kit
already has: `api-versioning` or `feature-flags`. Merging stays with the
engineer, one MR at a time, in order.

**C5. The five skills, smallest change each.** The rules live once in
`plugins/bearing/references/task-set.md` (new, about 60 lines, no
commands, so `lint-tools` has nothing to grant from it); each skill
adds a few lines and cites it.

| Skill | Change |
|---|---|
| `start-task` | New optional `--repos <Name,Name,...>` (names from the repo plan, or paths). Steps 1 to 7 run as today in this repository only. Step 7 also writes the `## Repos` section (`progress.py write --repo ...`) after the merge-order question, and the report ends with the exact `start-task <ID> <PascalName> --repos <same list>` line to run in each sibling. Run in a sibling with the same list, it finds the same id and writes the same section. Also gains `--flow site` (B). About 8 lines; 179 today. |
| `session-handoff` | With a `## Repos` section: run `progress.py set` and put its rows in the handoff under a `## Set` heading; Next names the repository the next action is in. About 4 lines; grant already present. |
| `definition-of-done` | One more item after sub-project 3's last: "task set" is `n/a` without a `## Repos` section; `pass` when `progress.py set` shows every repository before this one in the merge order `ready` or `merged`; else `fail` naming them. Grant: `Bash(python3 *skills/session-handoff/scripts/progress.py*)`. About 5 lines. |
| `merge-request` | With a `## Repos` section: the description gains a "Task set" block (each repository, its branch, its order, "merge after <name> | first"); the output contract gains `Set: <k> of <n>; merge after: <name> | first`. About 6 lines; 143 today. |
| `autopilot` | Builds in one repository as today (`design-stages.md:35-37`). When the repo plan holds more than one entry, the mr stage writes the `## Repos` section from the plan in merge order and the report lists the `start-task ... --repos` line for each sibling. About 3 lines plus 3 in `references/review-smoke-and-mr.md`. |

**C6. Finishing.** The set is finished when every member's progress
Status is `merged`; the engineer sets it after each merge, as today
(`merge-request/SKILL.md:137-141`). `progress.py set` shows the count;
`workflow` already runs `progress.py index` for "what is in flight"
(`workflow/SKILL.md:88`), unchanged.

## Anti-goals

- G1. No wildcard, no "every repository" value, no per-host opt-in, and
  no environment variable that turns pushing on.
- G2. No merge, no MR or PR creation, no tag, no release, no force push,
  no push of any branch but the current one, no push to a URL other
  than the `BEARING_AUTO_PUSH` entry whose key matches origin's url, and
  never to origin's configured url itself, under any setting. (amended
  2026-10-18: clean-clone push)
- G3. The raw `git push` verb row, the settings deny and the sandbox
  network allowlist do not change. The only path is `brg-push run` from
  the Stop hook.
- G4. No auto push on harnesses other than Claude Code; `brg-harness`
  output is unchanged.
- G5. No new skill, no new stack, no new hook script, no new lint target.
- G6. No cross-repository writes from one session; no workspace or
  monorepo manager; no tracker sub-tickets per repository.
- G7. The site flow does not get its own autopilot profile.

## Open questions for the user

Q1, Q2, Q4 and Q5 are closed by the user's decisions of 2026-10-18
(preflight R10): personal `bearing.env` only, `hotfix/*` allowed, one
session per repository, `nextjs` for sites. Q3 stays open.

- Q1. Opt-in location. The request says "the repository's bearing.env",
  which does not exist. This spec uses the personal `bearing.env` listing
  repositories. Alternative: a tracked `.bearing/config.json` key the
  team agrees in an MR, required in addition to the personal key.
- Q2. Should `hotfix/*` branches be excluded from auto push? This spec
  allows them (a branch push, not a merge).
- Q3. Is the push result printed on the next prompt enough, or should
  the Stop hook also show a one-line `systemMessage` at once?
- Q4. One session per repository for a task set (this spec), or support
  one session across repositories with `--add-dir`, which needs the
  sandbox write list widened per session?
- Q5. Default stack for the site flow: `nextjs` (this spec), or a static
  generator, which Bearing has no stack lane for today.

## Acceptance criteria

1. With no `BEARING_AUTO_PUSH`, every existing test passes unchanged and
   no Bearing code path runs `git push`
   (`tests/unit/guard_deny_table.sh`, `tests/unit/autopilot_state.sh`).
2. `brg-push check` prints one line per condition and
   `push-check: 8 conditions, M met`; exits 1 on any unmet; exits 2
   outside a git repository and prints "0 conditions checked".
   (amended 2026-10-18: clean-clone push)
3. Opted in, on `feature/ABC-1-X`, clean, gate fresh, a request
   present: a Stop that passes the gate clones the branch into a fresh
   temporary directory and pushes from it to the listed entry (a local
   bare repository in the test) with exactly
   `--no-follow-tags <entry> HEAD:refs/heads/feature/ABC-1-X`;
   `push-result` records the sha and the key, never the entry; no tag
   reaches the remote; the temporary clone is gone afterwards. (amended
   2026-10-18: clean-clone push)
4. Each of these refuses with its named condition and pushes nothing:
   `main`, `release/v1.2.0`, detached HEAD, dirty tree, stale gate, zero
   commits ahead, non-fast-forward remote, no request, a request for
   another sha, a request naming a protected or non-task branch,
   `bearing.env` newer than the session mark, origin's key not listed, a
   redirecting setting in the engineer's global git config. (amended
   2026-10-18: clean-clone push)
5. `brg-guard command 'bash /x/bin/brg-push run --id s'` exits 2;
   `brg-push check` and `brg-push request` are allowed.
6. `brg-config set auto-push x --user` (and `auto_push`, `AUTO.PUSH`)
   exits 2 and leaves `bearing.env` unchanged.
7. The pre-push hook, with an agent variable set, refuses every push
   with today's message, a `BEARING_AUTO_PUSH` entry or not, and refuses
   a tag-only push with `an agent push carries only branches`; `lib.sh`
   holds no opt-in code; both copies identical. (amended 2026-10-18:
   clean-clone push)
8. The autopilot `mr` gate passes when the upstream equals HEAD and
   `push-result` records it, and fails as today for any other upstream.
9. `make docs` reports the new flow count; `flow-steps.tsv` holds
   `site` rows; `brg-session next-step` returns the next `site` step
   when `.bearing/config.json` has `"flow": "site"` and the branch is a
   feature branch, and the `bugfix` step on a bugfix branch.
10. `progress.py set` prints one row per repository and the `set:` line,
    exits 1 on zero repositories or a missing path; `check` rejects a
    `## Repos` section with duplicate or missing order numbers.
11. Every row of the A8 table is changed as listed, and a test fails if a
    file in that table still carries an unqualified "never pushes"
    sentence.
12. `make lint-plugin-size` shows `bearing` at its pre-branch count plus
    2; every touched SKILL.md is 200 lines or fewer; `make check` ends
    with `check: passed`.
13. No repository code runs at push time. (amended 2026-10-18:
    clean-clone push) With the template hooks installed and edited to
    write a canary file, a `Makefile` whose `check` writes one, and
    `.git/config` holding `core.sshCommand`, `credential.helper`,
    `core.fsmonitor` and a `url.<x>.pushInsteadOf` of the entry, each
    writing a canary, a requested push lands at the listed entry and no
    canary exists. Exported `GIT_SSH_COMMAND`, `GIT_CONFIG_PARAMETERS`
    and `GIT_DIR` change nothing.
