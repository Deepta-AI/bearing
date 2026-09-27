---
name: upgrade-tools
description: 'Upgrades every installed Claude Code plugin and skill pack on this machine (plugins, gstack, skills CLI, GSD), versions before and after. Use when asked to "update the plugins", "upgrade the skills" or "update all".'
argument-hint: "[source to limit: Bearing | plugins | gstack | skills | gsd; default: all]"
allowed-tools: Read, Edit, Skill, Bash(bash *bin/brg-doctor*), Bash(claude plugin:*), Bash(git status:*), Bash(git pull:*), Bash(git fetch:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(git tag:*), Bash(git describe:*), Bash(git rev-parse:*), Bash(git symbolic-ref:*), Bash(git checkout:*), Bash(git apply:*), Bash(git clone:*), Bash(make:*), Bash(npx skills@1.7.0:*), Bash(cat:*), Bash(ls:*)
---

# upgrade-tools

An upgrade of agent tooling changes what can run with the engineer's
permissions, so every version is read before it is taken. Each source
moves on its own path, its before and after versions are recorded, and
the result is checked the way a teammate will receive it. Nothing is
installed from here; an absent source is a row that says so.

## Inputs

- Limit: `$1`; if absent, every source below.
- Scope. Two kinds of source, often both present:
  - Project-pinned: the repository records its tooling so teammates get
    the same versions. Signs: a lock or pin file (`tooling.lock`,
    `pinned-packs.txt`, a manifest of commits), git submodules, a
    checkout with its own `.git` under `.claude/skills/` or `tools/`, a
    `directory` marketplace in `.claude/settings.json`, a bootstrap
    script or make target that clones them, patches kept beside them.
    When the request names a repository, or the cwd has these, the pin
    is the source of truth: moving a checkout without its pin is undone
    by the next bootstrap, and a machine upgrader pointed at it bypasses
    the lock and its mirror.
  - Machine-wide: `claude plugin list` (every plugin with marketplace
    and version, updated with `claude plugin update <name>@<marketplace>`);
    gstack at `~/.claude/skills/gstack/VERSION`, upgraded only by the
    `gstack-upgrade` skill (it detects global, local or vendored installs,
    autostashes local edits, keeps a `.bak` and runs version migrations);
    skills-CLI packs from `npx skills@1.7.0 list -g`, the CLI version
    pinned in `${CLAUDE_PLUGIN_ROOT}/bin/pinned-packs.txt`; GSD Core
    (`~/.claude/skills/gsd-*` or the plugin list), upgraded only by the
    `gsd-update` skill, which backs up and restores user files.
- The project's rules for tooling: ADRs, SECURITY or CONTRIBUTING notes
  on who approves a new pack version, what may not be fetched, and which
  settings must hold (for example no proactive skills, telemetry off).
- Truth for "current version": the pin and the checkout's own VERSION
  (or `git describe --tags`), never a README table. Report any doc that
  disagrees.

## Steps

1. Inventory. For each source: pinned version and ref, the checkout's
   actual HEAD and VERSION, whether HEAD is detached
   (`git symbolic-ref -q HEAD` fails), `git status --porcelain`, local
   patches that belong to it, and the newest release its configured
   remote or mirror holds (`git fetch --tags`, `git tag --sort=-v:refname`).
   Name the repository's own skills (no remote, not pinned) and leave
   them out. Print "N sources found"; zero stops with "0 sources found".
2. Review before moving, for every source with a newer version,
   including ones you will not take:
   - Read the upstream diff old..new (`git diff <old> <new>`), not only
     the release notes. Look for `allowed-tools` widening (`Bash(*)`,
     new commands), new hooks, MCP servers, `curl`, `wget` or URLs,
     piped installers (`| sh`), install scripts, new skills, and files
     the pack now writes into the project.
   - Read the CHANGELOG entry of every skipped release, not only the
     newest. A release that renames or moves configuration makes the old
     keys silently ignored and the defaults return; that is the upgrade
     that quietly breaks a policy.
   - Hold a version the project's rules say needs sign-off, and quote the
     lines that trigger it. When a new capability is borderline (a skill
     that calls a network endpoint only when asked), say which way you
     read the rule and why. Whenever you mention that a newer version is
     available, state its risk in the same sentence.
   - The target is the newest release that passes review, not "newest
     or nothing": when the newest is held, review the ones between.
3. Blockers, each stops its own source only:
   - Dirty checkout: never stash, reset, branch or commit inside it; it
     is someone's work. Report the full path of every changed file and
     whether the new version changes the same file, and hold the source
     so its pin and checkout stay together.
   - Local patches (a patch file, or edits in `git status` that match
     one): reverse-apply (`git apply -R`), check the patch applies on the
     new version (`git apply --check`), move, reapply. When it fails only
     on context (upstream changed lines next to the patched ones), make
     the same change by hand on the new version, regenerate the patch
     file from `git diff` there, and show old and new patch; when
     upstream changed the patched lines themselves, hold the source and
     show the hunk.
4. Move a project-pinned source:
   - Detached checkout: `git pull` fails there; `git fetch --tags`, then
     `git checkout --detach <tag>`. Record the full commit of the tag.
   - Update the pin in the same change, version and full ref. Pin and
     checkout must agree afterwards; a pin naming a version the checkout
     is not at is worse than no upgrade.
   - Apply every configuration migration from step 2 to the project's
     config, writing the policy values explicitly rather than trusting a
     new default.
   - Rerun the pack's setup or link step so skills added by the release
     are linked; add paths it now writes into the project to `.gitignore`.
   - Update docs that state the version.
5. Verify the teammate path, not only your checkout. In a scratch copy,
   run the project's bootstrap twice: from a fresh clone, and on an
   existing checkout at the OLD pin with its patches applied, the state
   every teammate is in (the old patch applied, not the new one). A
   bootstrap that aborts there ("local changes would be overwritten")
   means the upgrade does not reach the team: make the smallest fix to
   the bootstrap and rerun both, or report it as a blocker with the
   recovery commands. The fix may restore the patched files of a source
   that has patches; it must still refuse, never reset, a checkout where
   people work, and reversing the new patch cannot undo the old one.
   Then run the project's check target and show its counts.
6. Machine-wide sources, when in scope:
   - Plugins: for a marketplace added from a local path
     (`claude plugin marketplace list`), apply step 3 in that checkout;
     on a branch `git pull --ff-only`, detached `git fetch --tags` and
     check out the tag. A URL marketplace:
     `claude plugin marketplace update <name>`. Then
     `claude plugin update <plugin>@<marketplace>`, one row each.
   - gstack: invoke the `gstack-upgrade` skill with the Skill tool and
     let it finish; never pull that checkout or run its setup directly
     (a bare pull skips its backup and migrations). Absent: the row is
     "stopped: gstack-upgrade missing" and the engineer runs `/gstack-upgrade`.
   - Skills-CLI packs: `npx skills@1.7.0 update` moves every pack at
     once, so run step 2 on each pack's diff first. If any pack fails
     review, do not run the bulk update; report it. A pack installed at
     a commit moves only by a reviewed commit in `pinned-packs.txt`.
   - GSD Core, only if installed: invoke the `gsd-update` skill; if it
     reports local patches the row says "reapply pending: /gsd-update
     --reapply". It rewrites its hooks in `~/.claude/settings.json`; that
     is expected.
   - Then `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-doctor"`.
7. Report. Do not commit, push or open a merge request: leave the change
   in the working tree and list the files to commit. Say how teammates
   get it (merge the pin change, rerun the bootstrap, restart Claude
   Code) and that Claude Code must be restarted for plugin or skill
   changes to load. Name what you did not verify.

## Output contract

```
## Upgrade: N sources (updated U, unchanged C, held H, not installed A)
| Source | Before | After | Available | Result |
| <source> (pinned or machine) | <v> | <v> | <v> | updated; <migrations, patches> |
| <source> | <v> | <v> | <v> | held: <reason, file or quoted line> |
Reviewed: <per source: new tools, hooks, network calls, or none>
Teammate path: fresh clone <ok|fail>, existing checkout <ok|fail>; <check> <counts>
Files to commit: <list> (not committed)
Not verified: <list>
Restart Claude Code to load the updated plugins and skills.
```

## Gotchas

- Pin and checkout move together or not at all.
- A patched vendored checkout blocks `git checkout` of a release that
  touches the patched file; the existing-checkout bootstrap run is there
  to catch it.
- A configuration key moved by a skipped release is ignored without an
  error; only reading every skipped changelog catches it.
- Held versions are still reported with the reason, so the next person
  does not take them blind.
- A failed update of one source does not stop the others.
- Do not edit `~/.claude/settings.json` by hand; `claude plugin` owns it.
  Nothing under `~/.claude` changes for a project-scoped request.
- A pack with its own upgrader (gstack, GSD) is machine-upgraded through
  it; its row never says "updated" from a bare pull or installer run.
