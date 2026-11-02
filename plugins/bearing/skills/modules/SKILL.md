---
name: modules
description: 'Installs, updates and lists module kits from a configured catalogue, and reports drift. Use when asked to "add the auth module" or "module drift".'
argument-hint: "add <module> --stack go|python | update [<module>] | list | drift"
allowed-tools: Read, Grep, Glob, Bash(bash *bin/brg-modules*), Bash(uvx copier@9.19.1 copy:*), Bash(uvx copier@9.19.1 update:*), Bash(git status:*), Bash(git diff:*), Bash(git ls-remote:*), Bash(ls:*), Bash(make check:*), Bash(make test:*), Bash(go test:*), Bash(uv run pytest:*), AskUserQuestion
---

# modules

A module kit is built, tested code for a part every product rebuilds
(authentication, IAM, notifications, health checks), kept as a Copier
template in a catalogue repository. This skill copies a module into the
product, where it becomes the product's own code, and pulls later fixes
in with Copier's 3-way merge.

The catalogue is optional and private to whoever runs one. Bearing ships
no catalogue url and works fully without it: with none configured, or no
access, the action stops with one line and the calling skill builds from
its own guidance.

Not this: the domain skills (`auth`, `logging`, `health-checks` and the
rest) design what a module does not cover; `dependency-audit` checks the
packages a module brings in.

## Inputs

- Action: `$1`, one of `add`, `update`, `list`, `drift`. Absent: `list`.
- Module and stack, for `add`: `$2` and `--stack go|python`. No stack:
  infer it from the repository (`go.mod` is go, `pyproject.toml` with
  FastAPI is python); both or neither, ask once with AskUserQuestion as
  `${CLAUDE_PLUGIN_ROOT}/references/console.md` says.
- Catalogue url: `BEARING_MODULES_REPO`, read by the helper from the
  environment, then plugin settings (`modules_repo`), then
  `~/.config/bearing/bearing.env`. Empty by default. Any git url form
  works, ssh aliases included (`git@my-alias:group/catalogue.git`).
- Helper: `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-modules" <command>`;
  commands `access`, `list`, `check <module> <stack>`, `installed`,
  `drift`. Exit 3 means no catalogue or no access; exit 4 means the
  catalogue does not list that module for that stack.
- Installed modules: one Copier answers file per module under
  `.bearing/modules/<module>.yml`; its `_commit` is the catalogue
  version it was rendered from, `_src_path` the url it came from.
- The product's gate: `make check` where a Makefile exists, else the
  stack's test command (`go test ./...`, `uv run pytest`).

## Steps

1. **Access first, every action.** Run
   `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-modules" access`. Exit 3: print
   its line, which starts "module catalogue not available, building from
   guidance", and stop this action with no error; a calling skill goes
   on with its own steps. Exit 2: the configured url was refused; quote
   it and stop. `drift` does its own check (step 5).
2. **add.** Run `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-modules" check <module> <stack>`.
   Exit 4: say the catalogue does not list it for that stack, print the
   helper's `list` so the user sees what is there, and stop. Status
   `next`: repeat the helper's warning in the report; the module works
   but has not met the catalogue's enterprise bar. An answers file for
   that module already present: this is an `update`, not a second copy;
   say so and stop. `git status --porcelain` not empty: stop and ask the
   user to commit first, because a render on a dirty tree mixes the
   module with their edits. Then, from the repository root:
   `uvx copier@9.19.1 copy -a .bearing/modules/<module>.yml --data module=<module> --data stack=<stack> <catalogue url> .`
   The catalogue's `copier.yml` needs more answers (service name, Go
   module path). The tool shell has no terminal for Copier's prompts, so
   pass every answer as another `--data key=value`: the ones the
   repository settles (the service name, the module path in `go.mod`)
   directly, the rest asked first with AskUserQuestion. Then run the
   product's gate and record its counts. A failure is reported with the
   output; nothing is reverted, because the files are uncommitted and
   `git status` shows them all.
3. **update.** With a module: its answers file. Without: every file in
   `.bearing/modules/`; zero files stops with "0 modules installed,
   nothing to update". Copier refuses a dirty tree, so one module per
   pass: `uvx copier@9.19.1 update -a .bearing/modules/<module>.yml` (a question
   the new version adds goes in as `--data`, as in step 2). Copier merges
   the catalogue's change with local edits; a conflict leaves inline
   markers or `.rej` files. List every conflicted file from
   `git status` and `git diff --name-only --diff-filter=U`, and grep the
   module's files for `<<<<<<<` and for `*.rej`. Never resolve one,
   never discard a side: report them and stop. With none, run the gate
   and print the commit command; the next module waits for that commit.
4. **list.** `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-modules" list`. It
   prints the catalogue's modules (name, stacks, status, version, and
   the tag read) and the modules installed here with their `_commit`.
   Print it as the helper wrote it.
5. **drift.** `bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-modules" drift`. It
   compares each installed module's `_commit` with the newest catalogue
   tag and ends with "drift: N modules checked against <tag>, B behind".
   Exit 1 with "0 modules installed" is a failure, not a pass: nothing
   was checked. Without access it prints
   `skipped: no catalogue access (N modules not checked)` and exits 3;
   report that line as skipped, never as passed. A module behind is
   fixed with `update`, which this action does not run.

## Output contract

```
## modules <action>
Catalogue: <url> at <tag> | module catalogue not available, building from guidance (<why>)
add: <module> for <stack>, version <v>, status <next|stable>; files: <n> new under <paths>
update: <module>: <clean | conflicts: file, file>; next module <waits for the commit | none left>
list: <the helper's table>; installed here: <n>
drift: <n> checked against <tag>, <b> behind: <module (commit)> | skipped: no catalogue access (<n> modules not checked)
Gate: <make check: counts | not run: why>
Not done: <conflicts to resolve, modules behind, answers the user still owes>
```

## Gotchas

- Copier picks the newest git tag of the catalogue; with no tag yet it
  renders the default branch, and `_commit` is then a commit id. The
  helper says which it read.
- `_src_path` in the answers file is the url used at install time.
  `copier update` reads it, not `BEARING_MODULES_REPO`, so an ssh alias
  that only exists on one laptop breaks updates in CI and on other
  machines. Install from a url every machine that updates can reach.
- A local edit inside a module folder is what makes `copier update`
  conflict. Product logic calls the module through its interface and
  lives outside the folder; a fix to the module goes to the catalogue.
- The catalogue lives behind access control; a product's CI needs read
  access (a deploy key or app) only to run `update` or `drift`, never to
  build, because the code is already in the product.
- `-a` keeps one answers file per module. Without it Copier writes
  `.copier-answers.yml` and the second module overwrites the first.
