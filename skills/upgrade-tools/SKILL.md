---
name: upgrade-tools
description: 'Upgrades every installed Claude Code plugin and skill pack on this machine (plugins, gstack, skills CLI, GSD), versions before and after. Use when asked to "update the plugins", "upgrade the skills" or "update all".'
argument-hint: "[source to limit: Bearing | plugins | gstack | skills | gsd; default: all]"
allowed-tools: Read, Skill, Bash(bash *bin/brg-doctor*), Bash(claude plugin:*), Bash(git status:*), Bash(git pull:*), Bash(npx skills:*), Bash(cat:*), Bash(ls:*)
---

# upgrade-tools

Every installed source, one command each, versions before and after,
a count, then the doctor. Nothing is installed from here; a source that
is absent is a row that says so (`doctor` prints the install
command).

## Inputs

- Limit: `$1`; if absent, every source below.
- Marketplace plugins: `claude plugin list` gives every installed
  plugin with its marketplace and version (Bearing, superpowers,
  frontend-design, code-review, claude-security, mattpocock-skills,
  mcp-server-dev, playwright and any other); each is updated with
  `claude plugin update <name>@<marketplace>`. For a marketplace added
  from a local path (`claude plugin marketplace list`), that checkout
  is pulled first; a URL marketplace is refreshed by
  `claude plugin marketplace update <name>`.
- gstack: `~/.claude/skills/gstack/VERSION`; updated by gstack's own
  upgrader, the `gstack-upgrade` skill (`~/.claude/skills/gstack-upgrade`),
  which detects a global, local or vendored install, carries local edits
  over the pull with `--autostash`, keeps a `.bak` copy and restores it
  when `./setup` fails, and runs the version migrations. Absent: the row
  is "stopped: gstack-upgrade missing" and the engineer runs `/gstack-upgrade`.
- skills-CLI packs: `npx skills list -g` (ui-craft, pm-skills,
  addyosmani, dash0, qa-skills, Vercel, conventional-changelog,
  trailofbits, playwright-cli); refreshed by `npx skills update`.
- GSD Core: `~/.claude/skills/gsd-*` or the plugin list; updated by
  GSD's own upgrader, the `gsd-update` skill, which backs up files the
  user added or changed (`gsd-user-files-backup/`, `gsd-local-patches/`)
  before it reinstalls and restores them after. Absent: the row is
  "stopped: gsd-update missing" and the engineer runs `/gsd-update`.
- Kit VERSION: `<Bearing>/VERSION` at the marketplace path or the plugin
  root; if unreadable, the version column shows the plugin list line.
- A clean tree in any local checkout that is pulled (safety stop, kept).

## Steps

1. Inventory: list every source present with its version before
   (`claude plugin list`, `cat ~/.claude/skills/gstack/VERSION`,
   `npx skills list -g`, `cat <Bearing>/VERSION`), `n/a` when absent.
   Print "N sources found". Zero sources: stop with "0 sources found;
   run install.sh".
2. Marketplace plugins: for each marketplace added from a local path,
   in that checkout `git status --porcelain` must be empty, else stop
   that row with the list of changed files; then `git pull --ff-only`
   there and `claude plugin marketplace update <name>`. Then
   `claude plugin update <plugin>@<marketplace>` for every installed
   plugin, one row each.
3. gstack: invoke the `gstack-upgrade` skill with the Skill tool and let
   it run end to end, including its own question and its changelog.
   Never pull that checkout or run `./setup` directly: a bare pull skips
   the backup, the autostash and the migrations, and a failed `./setup`
   leaves a half-built install with no copy to restore. Record the
   version it reports as the After column.
4. skills-CLI packs: `npx skills update`; one row per pack from
   `npx skills list -g` before and after.
5. GSD Core, only if installed: invoke the `gsd-update` skill with the
   Skill tool (no flag: the latest release). It backs up custom files,
   reinstalls, restores them and clears its cache; when it reports local
   patches, the row says "reapply pending: /gsd-update --reapply". It
   rewrites its own hooks in `~/.claude/settings.json`; that is
   expected. Never run its npx installer directly for the same reason
   as step 3.
6. Record versions after, run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-doctor"`
   (machine checks are enough from outside a repository), and print the
   table with the count of sources updated, unchanged, stopped and
   absent. Say plainly that Claude Code must be restarted for a plugin
   update to load.

## Output contract

```
## Upgrade: N sources (updated U, unchanged C, stopped S, not installed A)
| Source | Before | After | Result |
| bearing@bearing | ... | ... | updated | unchanged | stopped (dirty tree) |
| superpowers@claude-plugins-official | ... | ... | ... |
| <every other plugin> | ... | ... | ... |
| gstack | ... | ... | ... |
| skills: <pack> | ... | ... | ... |
| GSD Core | ... | ... | ... | not installed |
Doctor: <N> checks, <M> missing
Restart Claude Code to load the updated plugins.
```

## Gotchas

- Never `git pull` inside a checkout that has local changes; check
  `git status --porcelain` first and stop that row with the list if it is
  not empty. The other sources still update.
- A failed update of one source does not stop the others. Report each.
- `npx skills update` refreshes every pack the skills CLI manages at
  once; a pack that was copied by hand (LambdaTest, openai/skills) is not
  in its list and is reported as "manual".
- Do not touch `~/.claude/settings.json` by hand; `claude plugin` owns it.
- A pack with its own upgrader is upgraded through it. gstack and GSD
  both keep user edits across an upgrade only on their own path; the
  row for either never says "updated" from a bare pull or installer run.
- This skill needs no repository; run it from anywhere.
