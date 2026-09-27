---
name: tracker-sync
description: 'Creates and updates tickets in the configured tracker (Jira, GitLab, GitHub, REST or none): create, sync the backlog, move status, link MRs. Use when asked to "create the tickets", "sync to Jira" or "move TASK-142".'
argument-hint: "create <type> <title> | update <KEY> [--status s] [--assignee me] | sync [backlog] | trace <KEY> [--mr url] | get <KEY> | list | config"
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(bash *bin/brg-tracker *), Bash(git status:*), Bash(git diff:*), Bash(git branch:*), Bash(git log:*), Bash(git remote:*), Bash(git rev-parse:*), Bash(git merge-base:*), Bash(git symbolic-ref:*), Bash(make check:*), Bash(ls:*)
---

# tracker-sync

Every tracker call goes through `bin/brg-tracker` from the plugin
(`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-tracker" ...`), never an adapter
directly. It reads `BEARING_TRACKER` from the environment, then
`~/.config/bearing/bearing.env`, and dispatches to `bin/brg-jira`,
`bin/brg-gitlab`, `bin/brg-github` or `bin/brg-rest`. The adapters read
credentials and never print them; never open `bearing.env` yourself.

The script is the easy part. The value of this skill is deciding what is
true before anything is sent: which items already exist in the tracker,
which are not ready to file, what status the repository's own rules allow,
and whether the ticket's promises are actually met on the branch. Do that
analysis in full whether or not a tracker is reachable.

## Inputs

- Tracker: `brg-tracker config` (environment, then `bearing.env`).
- Backlog for `sync`: `$1`, else `docs/product/backlog.md`; test cases
  from `docs/testing/test-cases.md`.
- Git facts for `trace`: branch, remote, commits; the MR link from `--mr`
  or the user.
- The repository's own rules: README, CONTRIBUTING, the backlog header.

The command surface, identical for every tracker. Exit codes: 0 done,
1 failed with a one-line reason, 2 usage, 3 skipped because the tracker
is `none` (write commands).

```
brg-tracker config                 # effective tracker, source, id prefix; never secrets
brg-tracker me | get <KEY> | resolve <KEY>
brg-tracker list [--type t] [--status s] [--q text]
brg-tracker create --type <epic|story|task|bug|testcase> --title <s>
            [--description-file f] [--parent KEY] [--priority p]
brg-tracker update <KEY> [--status name] [--assignee me|email|login]
            [--title s] [--description-file f]
brg-tracker comment <KEY> (<text> | --file f)
brg-tracker link <KEY> <relates|blocks> <KEY2>
brg-tracker trace <KEY> [--branch b] [--mr url] [--commits a,b] [--tests ..] [--adr ADR-nnnn]
```

Adapter facts (hierarchy, how `--parent` maps, status names, what "link"
means on GitHub, the configuration keys each adapter needs) are in the
header comment of `bin/brg-tracker` and of each adapter script; read the
one for the configured tracker. The REST tracker protocol is in
`docs/TRACKERS.md` of the Bearing repository, which the plugin does not
ship.

## Steps

### Step 1: is the tracker reachable?

`brg-tracker config`, then `brg-tracker me`.

- Reachable: continue; every write below is real.
- `none`, env file absent, or a credential or host missing: this is a
  configuration, not an error. Do not stop there. Do Steps 2 and 3 in
  full as a dry run, write the payloads (Step 4) and end with exactly what
  the user must set (Output contract). Never invent a key, never ask for a token or
  password in the conversation, never point a client at another tracker or
  reuse credentials found for another service, and never hand-roll a
  request to the tracker.

### Step 2: read the repository's own rules

README, CONTRIBUTING, the backlog header: the project key and tracker URL,
where keys are recorded, the status workflow and the condition for each
status, the long-lived branch, how tests carry test case ids. These
override every default below.

### Step 3a: `sync [backlog]` and `create`

Source: `$1`, else `docs/product/backlog.md`; test cases from
`docs/testing/test-cases.md` (absent: that pass is 0, reported). No
backlog: offer a pasted list, the test case file, or `create` one at a time.

1. **Git state of the source.** `git status` and `git diff` on the
   backlog. Items that exist only as uncommitted edits are named in the
   report and filed only once committed (or on the user's say-so). Never
   commit, stash or discard someone else's edit.
2. **Existing keys, in every form.** An item is already in the tracker if
   anything ties a project key to it: its `Ticket:` line, any other
   `Jira:`/`Issue:`/`Key:` line or a key in its heading or text, a commit
   subject or body (`git log --all --format='%h %s%n%b' | grep
   '<PREFIX>-[0-9]'`), or a code or test comment naming the item's id or
   title (`grep -rn '<PREFIX>-[0-9]'`). Say what tied each key to its
   item. A key found only in history or code is still a key: no second
   ticket; propose recording it in the backlog.
3. **Duplicates the repository cannot show.** An item with no key
   anywhere may still have been filed by hand. When reachable, `brg-tracker
   list --q "<title words>"` for each before creating; when not, say this
   search is the first step of the filing run.
4. **Hierarchy.** Epics first, then stories with `--parent <epic key>`,
   then test cases under their story. An existing ticket whose epic is new
   is re-parented once the epic exists, not created again; `update` has no
   `--parent`, so `link` it to the epic and list the parent change for the
   user to make in the tracker.
5. **Readiness.** Hold an item back (report it, do not file it as ordinary
   work) when an acceptance criterion contradicts an Accepted ADR, a stated
   constraint or another item: name the criterion, the decision, and what
   would unblock it (rewrite the criterion, or a superseding ADR). Raising
   the conflict is yours; settling it is the user's, so no ADR or story
   text is edited. Flag items with no acceptance criteria.
6. **Bodies.** For each item to create, write its description file:
   narrative, every acceptance criterion with its `AC-` id verbatim,
   non-goals, its `TC-` ids, the ADRs it rests on. Every
   `--description-file` you name must exist when you finish.
7. **Counts.** Already in the tracker (keys, and how each was found), to
   create (epics, stories, test cases), held back, pending as uncommitted.
   Check they add up to the items in the backlog.
8. **Write-back, only with real keys.** When a create returns a key,
   record it as the repository's convention says (`Ticket: <KEY>`) and
   leave that change uncommitted for the user. Never write a placeholder,
   a guessed next number or a status note into the backlog.

### Step 3b: `update`, `trace`, and "mark it done"

1. **Base branch.** From CONTRIBUTING or README, else `git symbolic-ref
   refs/remotes/origin/HEAD`, else whichever of `origin/main`,
   `origin/master`, `origin/develop` exists. Never assume `develop`.
2. **Merged or not.** `git merge-base --is-ancestor HEAD origin/<base>`
   (remote-tracking refs are as of the last fetch; say so). A ticket goes
   to the done status only when the repository's rules are met (merged,
   and deployed if it says so). Otherwise propose the status its rules
   give for the current state (usually In Review for an open MR) and say
   what moves it on. The request's wording never overrides this.
3. **Commits.** `git log --format='%h %s' origin/<base>..HEAD`. Attach the
   ones whose subject carries this key. One carrying another key belongs
   to that ticket: note it, change nothing on it. List keyless ones for
   the user to place.
4. **Test cases: promised against delivered.** Take the ids the test case
   file assigns to this key. For each, a test must name it, run and pass.
   Run the suite (`make check` or the repository's command) and read its
   summary: a `todo`, `skip` or commented-out test is not coverage, and a
   commit subject claiming an id is not evidence. Report covered, missing
   and placeholder ids with counts ("2 of 3 covered; TC-104 is a todo").
5. **Behaviour against the decision.** For each ADR the branch adds or
   cites, quote its `Status:` line (Proposed is not Accepted) and check
   the code does what its Decision section says. A gap here or in step 4
   means the ticket is not complete against its own test cases; say so
   plainly, whatever status is proposed.
6. **MR link.** From `--mr` or the user. The remote gives the host and
   project (`git remote -v`), never the MR number: without the link, ask
   for it and leave the field empty, or give the branch URL on the
   remote's host. Never guess a number.
7. Run `brg-tracker update` and `brg-tracker trace` with those facts or,
   with no tracker, print them as exact commands (Step 4). Called from
   `merge-request`, exit 3 means "tracker: none", reported, not a failure.
   Status names match case-insensitively against what the tracker offers;
   an unknown name stops with the adapter's list.

`get`, `list`, `config`: print what the script returns.

### Step 4: payloads when nothing can be sent

Write each description or comment body to a file under `.scratch/tracker/`
in the repository (untracked; say so if it is not git-ignored). Print the
commands in filing order, with real keys where they exist and a named
placeholder only for a key the tracker will return:

```
brg-tracker create --type epic --title "Notifications" --description-file .scratch/tracker/E3.md
brg-tracker create --type story --title "..." --parent <E3 key> --description-file .scratch/tracker/NTF-2.md
brg-tracker link PROJ-88 relates <E3 key>         # already filed; set its parent to E3 by hand
brg-tracker comment PROJ-88 --file .scratch/tracker/PROJ-88-trace.md
```

Placeholders live only in these commands, never in the repository.

## Output contract

```
tracker: <rest | jira | gitlab | github | none> (<command>)
<key> <type> "<title>" status=<name>       # one line per ticket touched or planned
created N, updated N, comments N, links N, failed N, skipped N, held N
```

Then Changed, Verified, Not done, Noticed. Say plainly whether anything
was sent. With no tracker, name what to set, never the values: in
`~/.config/bearing/bearing.env` (template `templates/user/bearing.env` in
the plugin), `BEARING_TRACKER=<jira|gitlab|github|rest>` plus the keys
the adapter's header lists (for Jira `BEARING_TRACKER_URL`,
`BEARING_TRACKER_PROJECT`, `BEARING_TRACKER_EMAIL`,
`BEARING_TRACKER_TOKEN`), then rerun the printed commands. A suite you did
not run is "not run".

## Gotchas

- The `Ticket:` line is one place a key lives; the costly mistake is a
  duplicate of something filed from a standup or a spike.
- A grep hit for a `TC-` id is not coverage; read the runner's pass, skip
  and todo counts.
- A branch can carry another ticket's commit; attaching it misreports
  both tickets.
- An ADR's status is part of the trace: "cites ADR-0012 (Proposed)".
- On GitHub `link` is a pair of cross-reference comments, and on GitLab
  and GitHub a status is a label; report it that way, not as a workflow
  transition.
- `create` rejects an unknown type before the call; the five generic
  types are all any adapter accepts. What the generic surface does not
  cover (REST labels, points, due dates) is the adapter, run by the
  engineer.
