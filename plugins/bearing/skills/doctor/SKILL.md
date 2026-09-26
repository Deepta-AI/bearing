---
name: doctor
description: 'Checks this machine and repository are set up for this plugin: skill packs, hooks, CLAUDE.md import, rules, hooksPath, with a fix per miss. Use when asked to "check my setup", "is it installed" or a hook is missing.'
argument-hint: "[path to a repository, default: the current directory]"
allowed-tools: Read, Grep, Glob, Bash(bash *bin/brg-doctor*), Bash(command -v:*), Bash(claude plugin list:*), Bash(claude --version:*), Bash(git config:*), Bash(git rev-parse:*), Bash(ls:*), Bash(make -n:*)
---

# doctor

Runs `bin/brg-doctor` from the plugin and explains any failure in one line
each, with the exact command that fixes it.

## Inputs

- The doctor script: looks in `${CLAUDE_PLUGIN_ROOT}/bin/brg-doctor`; if
  the variable is unset, the Bearing path from `claude plugin list`; if
  that fails, `~/.claude/plugins/*/bearing*/bin/brg-doctor` by glob. None:
  the plugin is not installed, which is the first finding; run the
  machine checks inline (`command -v claude git make jq`,
  `claude plugin list` for superpowers, `~/.claude/skills/gstack/VERSION`,
  `~/.claude/CLAUDE.md`) and print them in the same shape.
- Repository: `git rev-parse --show-toplevel`; if absent, only the
  machine section runs and the report says "no repository: machine checks
  only". Nothing stops; a bare shell is a valid place to run this.
- Profile: `BEARING_PROFILE` in the environment, else in
  `~/.config/bearing/bearing.env` (`minimal`, `standard` or `full`, the
  `install.sh --profile` value). `standard` or `full` makes Superpowers
  and gstack required; unset or `minimal` makes them `optional`, so a
  minimal install can pass. `install.sh` does not write the key yet; add
  `BEARING_PROFILE=standard` by hand to make the packs a hard check.
- Nothing else. This skill reads; it never needs a scaffolded file.

## Steps

1. Run the doctor as in Inputs, from the current directory so the
   repository section applies when there is one.
2. Read its output. It prints one line per check, `ok`, `MISSING` or
   `optional`, then a summary `N checks, M missing, K optional`.
3. For every `MISSING`, print the fix:
   - plugin missing: `bash <Bearing>/install.sh` (or `claude plugin
     install bearing@bearing` once the marketplace is added)
   - a stack plugin reported `optional` (bearing-backend or bearing-apps)
     while this repository uses one of its stacks: `claude plugin install
     bearing-backend@bearing` or `claude plugin install bearing-apps@bearing`
   - superpowers missing: `claude plugin install superpowers@claude-plugins-official`
   - gstack missing: `bash <Bearing>/install.sh --skip-gsd --skip-superpowers`,
     which fetches gstack at the commit pinned in
     `${CLAUDE_PLUGIN_ROOT}/bin/pinned-packs.txt` and runs its `./setup`
   - gsd missing: `npx @opengsd/gsd-core@1.14.0 --global --claude` (the
     version pinned in `${CLAUDE_PLUGIN_ROOT}/bin/pinned-packs.txt`)
   - CLAUDE.md not importing AGENTS.md, rules missing, hooks path unset,
     Makefile without `check`, CI or MR template missing: `onboard-repo`
   - hooks path set to another directory (Husky's `.husky`) whose hooks
     do not all call `.githooks/<hook>`: add `.githooks/<hook> "$@" ||
     exit $?` to each of its three hooks, or set `core.hooksPath
     .githooks` by hand; never overwrite it from here
   - user CLAUDE.md missing: copy `${CLAUDE_PLUGIN_ROOT}/templates/user/CLAUDE.md` to `~/.claude/CLAUDE.md`
4. Report in the AGENTS.md shape: Changed (nothing), Verified (the checks
   that passed with their counts), Not done (the misses with fixes).

## Output contract

```
## Doctor: <N> checks, <M> missing, <K> optional (machine + repository <name> | machine only)
Changed: nothing
Verified: <list of ok lines>
Not done:
- <MISSING line>: <fix command>
```

## Gotchas

- Never fix anything from this skill. It diagnoses; `onboard-repo` and
  `install.sh` repair.
- A missing optional pack (GSD Core always; Superpowers and gstack unless
  `BEARING_PROFILE` is `standard` or `full`) is a note, not a failure. The
  script marks it `optional` and prints the profile it read.
- CI counts as present with `.gitlab-ci.yml` or any
  `.github/workflows/*.yml` or `*.yaml`.
- Half the checks are per repository; run from inside one to see them.
  From `~` or an empty directory the machine section alone is the whole
  answer, and the report must say so rather than report a clean bill.
- Inside the Bearing checkout itself the repository section is skipped by
  design (the kit is not a product repository).
