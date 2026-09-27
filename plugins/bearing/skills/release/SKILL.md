---
name: release
description: 'Prepares a release: version from commits or from the API diff for packages, CHANGELOG section, version bump, printed tag commands. Use when asked to "cut a release", "bump the version" or "publish the package".'
argument-hint: "[major|minor|patch|vX.Y.Z] [--package [path]]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p docs/releases), Bash(date:*), Bash(git tag -l:*), Bash(git tag --no-merged:*), Bash(git branch -a:*), Bash(git branch --no-merged:*), Bash(git describe:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(git status:*), Bash(git remote:*), Bash(git merge-base:*), Bash(git grep:*), Bash(make:*), Bash(go test:*), Bash(pnpm test:*), Bash(uv run pytest:*), Bash(./gradlew test:*), Bash(swift test:*), Bash(npm pack --dry-run:*), Bash(pnpm pack --dry-run:*), Bash(npm view:*), Bash(gorelease:*), Bash(apidiff:*), Bash(go doc:*), Bash(go list:*), Bash(griffe check:*), Bash(pnpm changeset status:*), Bash(pnpm exec nx show projects:*), Bash(pnpm exec turbo run build --dry-run:*)
---

# release

Version from what changed, changelog from the version, commands for the
engineer. A service or app takes its version from what its consumers see:
the commits, checked against the contract diff. A package (a library, an
SDK, a CLI others install) takes it from its exported surface: `--package`
adds the API diff, the pack check, the install snippet, the release order
and provenance. Never tags, pushes or publishes.

The job is mostly finding what the commit messages do not say: a breaking
change in a footer or in an unmarked refactor, a shipped hotfix this branch
lacks, a version string nobody listed, a secret the pack would ship. Every
finding goes in the final message with its mechanism, not only in notes.

Not this: `app-store-release` prepares an App Store or Play submission
and calls this skill for the version and changelog.

## Inputs

- Mode: `--package [path]` for a library, SDK or CLI; if absent, a
  service or app. A path without the flag, or a workspace with no
  deployable entrypoint, asks once which mode.
- Release branch: `develop` (or `release/*`) as the current branch; if
  the repository has no `develop`, `main`; else the HEAD branch from
  `git remote show origin`; else the current branch. Say which.
- Clean tree: `git status --porcelain`; if dirty, list the files and ask
  once: commit first, or continue (the report then says which files the
  release commit would sweep in).
- Last tag: `git describe --tags --abbrev=0`; in a workspace
  `git tag -l '<name>@*'`; none means `v0.0.0` and everything counts.
  When the user names the last version, compare: a disagreement is
  reported, the tags win.
- Shipped but unmerged: `git tag --no-merged HEAD` and
  `git branch -a --no-merged HEAD` (`hotfix/*`, `release/*`). A release tag
  there is a version users run whose fix this branch lacks: releasing
  as-is regresses it. Resolve it per the written policy (merge the branch
  back, its test and CHANGELOG section with it, and say so), or stop and
  report it as the first blocker. Never describe the new version as
  containing a fix the branch does not have. The new version is above
  the highest release tag anywhere, not only on this branch.
- Bump: `$1` overrides the derived bump, with a warning when it is lower.
- Version fields: the manifest (`VERSION`, `package.json` and `app.json`,
  `pyproject.toml`, `app/build.gradle.kts`, `project.yml`), then
  `git grep -nF '<old version>'` for every other copy: code constants,
  Helm `Chart.yaml` `appVersion` (the image tag defaults to it), Dockerfile
  labels, `openapi` `info.version` when it tracks releases, README pins.
  A README that says "the version lives in X and Y" is not a complete
  list. Leave dependency pins and old changelog lines alone. None found:
  create `VERSION` and say so.
- Package (`--package` only):
  - packages: the path, else the root; in a workspace
    (`pnpm-workspace.yaml`, `package.json` `workspaces`, `go.work`, a uv
    workspace) every package whose files changed since its last tag;
  - ecosystem: `package.json`, `go.mod` or `pyproject.toml`; none: stop
    with "no package manifest found";
  - API diff tool: npm from the `exports` field and the `.d.ts` entry at
    both refs; Go `gorelease`, else `apidiff`, else `go doc -all`; Python
    `griffe check <pkg> --against <tag>`, else `__all__`; no tool: the
    entry files diffed by hand and the report says `manual`;
  - registry: `.npmrc`, `publishConfig`, `[[tool.uv.index]]`, `GOPROXY`;
    absent: the public registry, said so;
  - CI publish job: a publish step in the CI file; absent: provenance is
    `none (laptop publish)`.
- Changelog: `CHANGELOG.md`, or `.changeset/*.md` when `.changeset/`
  exists; absent: created with a Keep a Changelog header.
- Gate: `make check` when the Makefile has a `check` target; else the
  stack's native command (`go test ./...`, `pnpm test`, `uv run pytest`,
  `./gradlew test`, `swift test`) and the report says it is improvised.
- Policy: CONTRIBUTING.md, RELEASING.md, the CI file. Read, obeyed where
  possible, never edited to make the release fit. A rule that cannot be
  met (provenance from a laptop, a sign-off that did not happen) is a
  finding for the engineer, with the options.

## Steps

1. Resolve the mode, branch, tree, last tag and unmerged release tags as
   in Inputs. `--package`: print "N packages, last tag <tag>"; zero
   changed: stop with "0 packages changed since <tag>".
2. Commits since the tag, full messages:
   `git log --format='%h %s%n%b%n--' <tag>..HEAD` (with `-- <path>` per
   package); the subject alone misses a `BREAKING CHANGE:` footer. Zero
   commits: stop with "0 commits since <tag>". Classify: `feat` minor,
   `fix|perf` patch, `!` or a `BREAKING CHANGE:` footer major. A revert
   cancels its target: neither goes in the changelog as shipped. A commit
   without a Conventional prefix, or a `refactor`/`chore` touching
   shipped code, is read as a diff (`git show <sha>`) and classified by
   effect; list what it changed for users (response shape, log format,
   config keys, defaults, CLI flags). When unprefixed commits are the
   majority, ask for the bump.
   Service: diff the contract since the tag (`git diff <tag> -- api/
   '*.proto' '*openapi*'`, JSON tags on response types). A removed or
   renamed field is major whatever the messages say; name every endpoint
   that returns it. A service's major changes no module path (`/vN` is for
   libraries others import).
3. `--package` only, the version from the surface:
   - diff the exported surface with the tool from Inputs and print "S
     symbols before, T after: removed R, added A, changed C"; zero at both
     refs: stop with "0 exported symbols; check the entry point";
   - any removed or changed symbol (a renamed option counts) is major
     (minor while 0.x), only added is minor, none is patch; print the
     commit bump beside it; the diff wins and the report says so;
   - runtime floor: compare `engines`, `requires-python` or the `go`
     directive with what the code now calls (for example
     `Array.prototype.toSorted` needs Node 20, `str.removeprefix` Python
     3.9), from the runtime's own release notes, not memory of CI.
     Code above the declared floor is breaking for users on the old
     runtime: raise the floor as a Breaking line, or report it as a
     blocker. CI testing only the newest runtime hides it;
   - pack check: `npm pack --dry-run` (or `pnpm pack --dry-run`). Know the
     rule: a `.npmignore` replaces `.gitignore` for npm, so every
     git-ignored file (`.env*`, keys, coverage) ships unless `files`
     excludes it. The fix is a `files` allowlist in `package.json`; a
     patched `.npmignore` fails open again on the next new file. Also
     tests, `src/` beside `dist/`, unintended `*.map`, missing `LICENSE`
     or `README.md`. Go: a major carries `/vN` in the module path
     (`go list -m`); Python: the wheel `packages` list. Print the file
     count, and rerun after the fix;
   - a secret found in the pack: name the file and key, never the value
     (do not print the file; `grep -c` or key names only). Check the
     previous tag's pack rules (`git show <tag>:.npmignore`, `files` at the
     tag): if earlier releases could have shipped it, tell the engineer to
     inspect the published tarball and rotate the credential. Never
     delete or edit the engineer's local file;
   - README install snippet (`npm i`, `pnpm add`, `go get`, `pip
     install`, `uv add`): the name equals the manifest name (not an old or
     deprecated name) and a pinned version equals the new one; the usage
     shows the current API, not a removed or renamed one;
   - workspace order: the dependency graph (`pnpm exec nx show projects
     --affected`, `pnpm exec turbo run build --dry-run`, else the
     `dependencies` fields), topological, every dependent of a bumped
     package at least a patch;
   - provenance: npm `--provenance` and PyPI trusted publishing need a CI
     job with OIDC; from a laptop `npm publish --provenance` fails. Go is
     covered by the checksum database; binaries and images get a Sigstore
     `cosign sign` line. The printed publish command carries provenance
     only when that job exists; otherwise say what is missing.
4. CHANGELOG: `## [X.Y.Z] - YYYY-MM-DD` above the previous section (and
   above any merged-back hotfix section), one section set for both modes:
   Breaking, Added, Fixed, Changed, Security, Docs. One line per change a
   reader will notice, task id kept, Conventional prefix removed. Each
   Breaking line carries a migration derived from the old code at the tag
   (`git show <tag>:<file>`), exact to the argument: a removed helper that
   wrapped another with a shifted argument maps to the shifted call, and
   a quick run of old against new confirms it when cheap. With changesets:
   `pnpm changeset status`, and every changed package needs a changeset
   (count).
5. Bump every version field from Inputs; Android `versionName` plus
   `versionCode` incremented; iOS `MARKETING_VERSION` plus the build
   number. `--package` writes `docs/releases/<name>-<version>.md` from
   `templates/RELEASE_CHECKLIST.md` only when `docs/releases/` already
   exists; otherwise the checklist's content goes in the report.
6. Run the gate. Leave the repository in one stated state: the release
   commit (untagged) on the release branch, or the edits uncommitted on
   it; never a merge in progress, a half-staged tree or edits on another
   branch. Then print for the engineer, and nothing else runs:
   ```
   git add <each file the release changed> && git commit -m "chore(release): vX.Y.Z"   (skip if committed)
   git tag -a vX.Y.Z -m "vX.Y.Z"                             (<name>@X.Y.Z in a workspace)
   git push origin <release branch> --follow-tags
   npm publish --access public                               (--package: + --provenance only from CI OIDC | pnpm changeset publish | uv publish | none for Go)
   ```
   Name the files; adding everything (git add with -A) sweeps untracked
   files (an env file, a scratch dump) into the release. Add the `release/vX.Y.Z` branch step
   when the policy says so.
7. Print the output contract, then the changelog section and the gate
   tail.

## Output contract

```
## Release: <name> v<before> -> v<after> (<major|minor|patch>, <service|package>, branch <name>)
Blockers: <none | each, with why and the fix>
Commits since <tag>: N (feat a, fix b, reverted r, unprefixed u: <what each changed>)
Why <bump>: <the footer, contract field or symbol that decided it; commits alone said <bump>>
Consumers: <who breaks and on which endpoints or symbols, and the migration>
Surface: S -> T symbols; removed R, added A, changed C                                        (package)
Pack: N files; <finding and its mechanism | none>   Secrets: <file:key, rotate? | none>        (package)
Provenance: <what the publish command claims and why>                                         (package)
Order: <a>, <b>, <c>                                                                           (workspace)
Version fields: <each file edited>   CHANGELOG: section added | file created | changesets N of N
Policy conflicts: <none | rule, why it cannot be met, options>
Gate: make check: passed | <native command> (improvised): passed | not run
State: <committed on <branch> as <sha> | uncommitted on <branch>>
Commands for the engineer:
  <lines>
```

## Gotchas

- Never tags, pushes or publishes. `--dry-run` is the only pack flag the
  agent runs; the real commands are printed.
- Secret values never appear in the report, the changelog, a commit or a
  command line; name the file and the key.
- A removed export is breaking even when nobody is thought to use it.
  The diff decides; a guess about consumers does not. Do not restore it
  or add an alias to dodge the major unless asked; propose it instead.
- A `.env` in a published tarball is unrecoverable: unpublish is limited
  and mirrors keep the file. Rotation is the only fix.
- Go: a major bump of a library is a new module path (`/v2`); a `v2.0.0`
  tag without it is invisible to `go get`. A service keeps its path.
- Python: `__all__` is the surface only when it is defined; without it
  every public name counts.
- Publishing a dependent before its dependency leaves a window where the
  registry holds a package that cannot install.
- Provenance cannot come from a laptop; a signed claim without CI OIDC is
  false in the release notes.
- Do not invent release facts (deploy dates, consumer counts, partner
  names) the repository does not hold.
- "Misc fixes" is not a changelog entry. A mobile release also needs
  store metadata: `app-store-release`.
