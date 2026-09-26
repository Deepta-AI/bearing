# Install the Bearing workflow

For every developer, once per machine. Ten minutes. The handbook
(the site in `site/`, published where GitLab Pages is enabled, or the
project wiki from `make wiki`) covers the same ground; this page is
the reference.

## 1. Prerequisites

- A coding harness. The plugin path needs Claude Code 2.1 or newer
  (`claude --version`) signed in with a seat; any other harness goes
  through step 6 instead.
- git, node 22 or newer (GSD Core wants 24 and warns on older), make, jq.
  macOS: bash 3.2 is fine; `brew install jq make shellcheck` (shellcheck is
  only for developing the kit).
- SSH access to the git host that holds your fork of bearing.

## 2. Install

```bash
git clone <your fork url> ~/bearing
bash ~/bearing/install.sh                     # profile standard
```

Flags: `--profile minimal|standard|full`, `--dry-run` (print every action,
touch nothing), `--no-claude` (no claude CLI steps; see step 6),
`--skip-gsd`, `--skip-gstack`, `--skip-superpowers`, `--skip-packs`,
`--remote <git url>`, `--uninstall`.

What it does, in order, skipping anything already present:

1. Registers `~/bearing` (or `--remote`) as the marketplace `bearing` and
   installs the plugin `bearing@bearing` at user scope.
2. Writes `~/.config/bearing/bearing.env` from `templates/user/bearing.env`
   with placeholders, mode 600. It never overwrites an existing file.
3. Copies a personal `~/.claude/CLAUDE.md` starter if you have none. Open
   it and put your name and role on the first line.
4. Profile `standard` and up: installs Superpowers from the official
   marketplace, clones gstack into `~/.claude/skills/gstack` and runs its
   setup, installs GSD Core globally (`npx @opengsd/gsd-core@latest
   --global --claude`).
5. Profile `full`: runs `bin/brg-install-packs` for the open-source skills
   the workflow names as main choices (ui-craft, Vercel, pm-skills,
   addyosmani, OpenTelemetry, qa-skills, Conventional Commits, Trail of
   Bits, mattpocock, mcp-server-dev, playwright, frontend-design,
   code-review, claude-security). The list with licences is in
   `docs/THIRD_PARTY.md`.
6. Runs `brg-doctor` and prints what it found.

Last line: `install.sh: N installed, M already present, K skipped, 0
failed`. Restart the harness; plugins load at start.

## 3. Configure

Edit `~/.config/bearing/bearing.env`. Every key, with its default:

| Key | Meaning | Default |
| --- | --- | --- |
| `BEARING_TRACKER` | none, jira, gitlab, github or rest (any server speaking the REST tracker protocol in [TRACKERS.md](TRACKERS.md)) | `none` |
| `BEARING_TRACKER_URL` | base url of the tracker | empty (gitlab.com and github.com for those adapters) |
| `BEARING_TRACKER_PROJECT` | Jira project key, group/repo, owner/repo, REST tracker project key | empty |
| `BEARING_TRACKER_EMAIL` | login email for Jira and the REST tracker | empty |
| `BEARING_TRACKER_TOKEN` | Jira API token, GitLab or GitHub token, or a REST tracker bearer token; GitLab and GitHub may rely on `glab auth` or `gh auth` instead | empty |
| `BEARING_TRACKER_PASSWORD` | REST tracker password when no token is set | empty |
| `BEARING_TRACKER_DONE_STATUS` | the status `brg-tracker close` moves a ticket to | `Done` |
| `BEARING_TRACKER_MAX_PAGES` | the most pages `brg-tracker list` follows before it stops and says so | `20` |
| `BEARING_TASK_ID_PREFIX` | force the id prefix in branch names (PROJ, GH, GL); empty accepts any `[A-Z][A-Z0-9]*-<n>` or `NOTASK-<n>` | empty |
| `BEARING_GIT_HOST` | which host's CI and change template a repository gets: gitlab, github or both | `both` |
| `BEARING_KIT_REMOTE` | git url of the fork developers install from | the checkout's own remote |
| `BEARING_ORG_ID` | reverse-domain id for mobile bundle ids | `com.example` |

`BEARING_TRACKER=none` is a valid, complete configuration: every ticket step
is skipped with a note. Check the result with `~/bearing/bin/brg-tracker
config`; its first line reads `tracker: <name> (from file)` and it never
prints a credential. The adapters, key shapes and command surface are in
[TRACKERS.md](TRACKERS.md).

## 4. Verify

In any repository on this standard:

```
doctor
```

Last line: `brg-doctor: N checks, 0 missing, M optional`. A `MISSING`
line names the fix. Either git host counts: `.gitlab-ci.yml` or
`.github/workflows/*.yml` as CI, `.gitlab/merge_request_templates/Default.md`
or `.github/PULL_REQUEST_TEMPLATE.md` as the change template. In a
repository that has not adopted the standard yet, run `onboard-repo --stack
<id>` (ids: `react-web`, `next-app`, `node-api`, `go-api`, `go-cli`,
`python-api`, `python-cli`, `data-pipeline`, `react-native`,
`flutter-app`, `android`, `ios`, `infra`). Both `new-repo`
and `onboard-repo` read `BEARING_GIT_HOST` and create the stack's lockfile when
the toolchain is installed.

Then try the workflow on a real task:

```
workflow                       # says what comes next
start-task TASK-142 InvoiceTotals    # creates the branch and the state file
```

## 5. What changed on your machine

| Path | What |
| --- | --- |
| `~/.config/bearing/bearing.env` | your configuration, mode 600, yours to edit, never overwritten |
| `~/.claude/settings.json` | marketplace `bearing` and the enabled plugins (managed by `claude plugin`) |
| `~/.claude/plugins/` | the installed plugin copies |
| `~/.claude/skills/gstack/` | gstack (profile standard and up) |
| `~/.claude/skills/*` | the skills-CLI packs (profile full) |
| `~/.claude/CLAUDE.md` | your personal notes (yours to edit) |

Nothing is written into any repository by the installer. Repositories get
their files from `new-repo` or `onboard-repo`, committed like any other
change.

## 6. Other coding harnesses

Everything in the standard except the Claude Code subagents and
permission list is harness-neutral: AGENTS.md is the canon, the Makefile
is the gate, the git hooks enforce commit shape, formatting and the rule
that a person pushes (the pre-push hook asks for the branch name on the
terminal, which an agent cannot type), and the guard logic lives in
`bin/brg-guard`. For Cursor, Codex, Gemini CLI, Copilot, OpenCode,
Windsurf, Cline, Zed or Kiro:

```bash
bash ~/bearing/install.sh --no-claude      # once per machine: kit checkout and env file
cd <product repo>
~/bearing/bin/brg-harness cursor           # or codex, gemini, copilot, opencode, windsurf, cline, zed, kiro, all
```

From Claude Code the same step is `harness-setup cursor`. It converts the
path-scoped rules, writes the harness's instruction pointer to AGENTS.md,
vendors the guard as `.bearing/bin/brg-guard` with the hook adapters under
`.bearing/hooks/`, and installs the Bearing skills through the skills CLI
(`npx skills add <kit git url> --all -a cursor -g -y` does the last step
by hand). Commit `.bearing/bin` and `.bearing/hooks`; `.bearing/state/` stays
ignored. `doctor` checks that the vendored guard's version stamp
matches the installed kit. The matrix of what each harness supports is in
`skills/harness-setup/references/harness-matrix.md` and in the handbook.

## Keep the skill listing lean

Claude chooses a skill from a listing Claude Code sends every turn, and that
listing is capped at 1% of the context window (about 8,000 characters on a
200k model). Past the cap, skills you have not used lately are listed by
name only. With several skill packs installed it is easy to pass 300 skills
and 80,000 characters, and then most skills trigger only by name. Bearing is
built for that: every skill name says its job and every description puts the
job and the trigger phrases first, in 220 characters or fewer. To keep
triggering reliable on your machine:

- Count what you load: `ls ~/.claude/skills | wc -l`, plus each plugin's
  `skills/` folder under `~/.claude/plugins/cache/`.
- Remove duplicates. Two plugins that ship the same skills (for example the
  document and example packs from one marketplace) double the cost for
  nothing: `claude plugin uninstall <name>@<marketplace>`.
- Hide the parts of a large pack you do not use, with the pack's own
  switch where it has one.
- Raise the budget if you accept the cost: `"skillListingBudgetFraction": 0.02`
  in `~/.claude/settings.json` doubles the listing (about 2,000 more tokens
  per turn on a 200k model).
- Never set `disable-model-invocation: true` on a skill you want Claude to
  pick up from plain requests. It hides the skill from Claude entirely,
  name included; only typing `/<plugin>:<name>` still reaches it.

## 7. Upgrade

```
upgrade-tools
```

It pulls the kit, updates the plugin (`claude plugin update bearing@bearing`),
gstack (pull and `./setup`), the skills-CLI packs (`npx skills update`)
and GSD Core, prints versions before and after with a count, and reruns
the doctor. Restart the harness afterwards. Read `CHANGELOG.md` for the
version you are crossing.

## 8. Uninstall

```bash
bash ~/bearing/install.sh --uninstall
```

It removes the plugin and the marketplace, asks before removing the env
file, removes `~/.claude/CLAUDE.md` only while it is still the untouched
template, and prints how to unhook each repository. Superpowers, gstack
and GSD Core are independent: `claude plugin uninstall
superpowers@claude-plugins-official`, `rm -rf ~/.claude/skills/gstack`,
and the GSD Core uninstaller. `npx skills remove <name> -g` drops one
skills-CLI pack.

## The handbook site on Vercel

Where the git host has no Pages, the `handbook:vercel` job publishes the
same site to Vercel on every merge to main: public to anyone with the link,
never indexed (robots.txt, a `noindex` meta tag and an `X-Robots-Tag`
header). One-time setup:

1. In Vercel, create a project (any name, framework "Other") without
   connecting a git repository; the CI job uploads the built site.
2. Create an access token (Account Settings, Tokens) scoped to that team.
3. Read the ids from the project's Settings, General: the Project ID, and
   the Team ID (or your user id for a personal account).
4. In the repository's Settings, CI/CD, Variables, add `VERCEL_TOKEN`,
   `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID`, each masked and protected.

The next pipeline on main ends with `handbook:vercel: N script bundles
deployed to <url>`. Without the three variables the job does not run.
Add a custom domain in the Vercel project if the default one is not wanted.

## The developer guide on Vercel

`devguide/` is a second site for the people who maintain the kit: how the
hooks, the guard, the skills, the scripts and the scaffolding work inside,
with terminal replays and recipes for changing each part. It is built from
the repository itself (`bin/gen-devguide.py`, checked by `make lint-docs`)
and deployed by the `devguide:vercel` job to its own Vercel project, public
by link and never indexed, like the handbook. One-time setup:

1. In Vercel, create a second project (framework "Other"), without a git
   repository.
2. In the repository's CI/CD variables, add `VERCEL_DEVGUIDE_PROJECT_ID`
   (masked and protected). `VERCEL_TOKEN` and `VERCEL_ORG_ID` are shared
   with the handbook job.
3. Optionally add `DEVGUIDE_REPO_URL`, the repository's web address; the
   guide then links every source file it names.

The next pipeline on main ends with `devguide:vercel: N script bundles
deployed to <url>`. To build or deploy by hand:

```bash
make devguide
cd devguide/dist && npx vercel@59.26.0 deploy --prod
```

Re-record the terminal replays after a change to what they show:
`python3 devguide/scripts/record.py` (all) or with one session name.

## The docs as wiki pages

The `pages` job publishes the handbook site only where the git host
serves GitLab Pages (a self-managed GitLab needs its administrator to
enable it). Without Pages, export the docs and the four task flows to the
project wiki. Enable the wiki (Settings, General, Visibility), create any
first page in the web UI so the wiki repository exists, then:

```bash
git clone <repository ssh url without .git>.wiki.git ../bearing-wiki
make wiki WIKI_DIR=../bearing-wiki REPO_URL=https://<host>/<group>/<project>
cd ../bearing-wiki && git add -A && git commit -m "docs: export from <commit>" && git push
```

The last line of `make wiki` reads `gen-wiki: N pages and a sidebar
written ... 0 made plain text ...` and names the base the repository links
point at; `REPO_URL` is the web address, which can differ from the ssh
host. Every page opens with the source file and commit it came from, so a
stale page says so. Edit the source in this repository and export again;
an edit made in the wiki is overwritten by the next export.

## Troubleshooting

- `doctor` says the plugin is missing right after install: restart the
  harness; plugins load at start. If `claude plugin list` does not show
  `bearing@bearing`, rerun `install.sh` and read its summary for a `FAILED`
  line.
- A skill does not fire on a phrase: name it (`merge-request`) or ask "use the
  merge-request skill". Command skills never fire on their own. If an auto skill
  should have fired, open a change on Bearing adding the phrase to its
  description.
- The doctor says MISSING but you use GitHub: it accepts either host's CI
  and change template; MISSING means neither exists. Set
  `BEARING_GIT_HOST=github` and run `onboard-repo` again.
- `make check` says gates skipped: `check: R gates run, S skipped` with S
  above zero means a tool is missing (`make doctor` names it). Install it,
  or locally run `BEARING_ALLOW_SKIP=1 make check` to see the rest. CI never
  sets it.
- The guard blocked a command you know is safe: it fails closed on
  anything it cannot tokenise and looks through `sudo`, `env`, `sh -c`,
  `xargs` and `git -C`. Run the command in your own terminal. A wrong
  verb is fixed in `bin/brg-guard` in the kit, never in
  `settings.local.json`.
- The marketplace add fails on the SSH URL: clone the repo first and pass
  the path: `bash install.sh --remote ~/bearing`.
- `git push` is refused inside the harness: that is the standard working.
  Run the printed command in your own terminal.
- The ticket step says `tracker: none`: `BEARING_TRACKER` is unset or none,
  which is valid. Fill the env file to connect a tracker.
- GSD Core warns about node: it wants node 24; harmless for the rest of
  the kit. Upgrade node or pass `--skip-gsd`.
