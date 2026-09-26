---
name: release
description: 'Prepares a release: version from commits or from the API diff for packages, CHANGELOG section, version bump, printed tag commands. Use when asked to "cut a release", "bump the version" or "publish the package".'
argument-hint: "[major|minor|patch|vX.Y.Z] [--package [path]]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p docs/releases), Bash(date:*), Bash(git tag -l:*), Bash(git describe:*), Bash(git log:*), Bash(git diff:*), Bash(git show:*), Bash(git status:*), Bash(git remote:*), Bash(git merge-base:*), Bash(make:*), Bash(go test:*), Bash(pnpm test:*), Bash(uv run pytest:*), Bash(./gradlew test:*), Bash(swift test:*), Bash(npm pack --dry-run:*), Bash(pnpm pack --dry-run:*), Bash(npm view:*), Bash(gorelease:*), Bash(apidiff:*), Bash(go doc:*), Bash(go list:*), Bash(griffe check:*), Bash(pnpm changeset status:*), Bash(pnpm exec nx show projects:*), Bash(pnpm exec turbo run build --dry-run:*)
---

# release

Version from what changed, changelog from the version, commands for the
engineer. A service or app takes its version from the commits. A package
(a library, an SDK, a CLI others install) takes it from its exported
surface, because the surface is the contract: `--package` adds the API
diff, the pack check, the install snippet, the release order and
provenance. Never tags, pushes or publishes.

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
  once: commit first, or continue (the release commit then includes them,
  which the report says).
- Last tag: `git describe --tags --abbrev=0`; in a workspace
  `git tag -l '<name>@*'`; none means `v0.0.0` and everything counts. A
  tag not on this branch's history (`git merge-base --is-ancestor`): ask
  once; never guess.
- Bump: `$1` overrides the derived bump, with a warning when it is lower.
- Version file: `VERSION`, `package.json` and `app.json`,
  `pyproject.toml`, `app/build.gradle.kts`, `project.yml`, `go.mod` (for
  a major's module path); none found: create `VERSION` and say so.
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
- Release branch policy: CONTRIBUTING.md; absent: no `release/vX.Y.Z`
  step and the report says the policy is unwritten.
- Checklist template (`--package`): `templates/RELEASE_CHECKLIST.md`.

## Steps

1. Resolve the mode, branch, tree and last tag as in Inputs. `--package`:
   print "N packages, last tag <tag>"; zero changed: stop with "0
   packages changed since <tag>".
2. Commits since the tag: `git log --format='%s' <tag>..HEAD` (with
   `-- <path>` per package). Zero commits: stop with "0 commits since
   <tag>". Classify: `feat` minor, `fix|perf` patch, `!` or `BREAKING
   CHANGE` major; commits without a Conventional prefix count as patch
   and are listed, and when they are the majority ask for the bump.
3. `--package` only, the version from the surface:
   - diff the exported surface with the tool from Inputs and print "S
     symbols before, T after: removed R, added A, changed C"; zero at both
     refs: stop with "0 exported symbols; check the entry point";
   - any removed or changed symbol is major (minor while 0.x), only added
     is minor, none is patch; print the commit bump beside it; the diff
     wins and the report says when they disagree;
   - pack check: `npm pack --dry-run` (or `pnpm pack --dry-run`), and fix
     through `files` any `.env*`, tests, `src/` beside `dist/`, unintended
     `*.map`, missing `LICENSE` or `README.md`; Go: a major carries `/vN`
     in the module path (`go list -m`); Python: the wheel `packages` list.
     Print the file count;
   - README install snippet (`npm i`, `pnpm add`, `go get`, `pip
     install`, `uv add`): the name equals the manifest name and a pinned
     version equals the new one; missing, write an Install section;
   - workspace order: the dependency graph (`pnpm exec nx show projects
     --affected`, `pnpm exec turbo run build --dry-run`, else the
     `dependencies` fields), topological, every dependent of a bumped
     package at least a patch;
   - provenance: npm `--provenance` and PyPI trusted publishing need CI
     OIDC; Go is covered by the checksum database; binaries and images
     get a Sigstore `cosign sign` line. Write what applies.
4. CHANGELOG: `## [X.Y.Z] - YYYY-MM-DD` above the previous section, one
   section set for both modes: Breaking (each with its migration line),
   Added, Fixed, Changed, Security, Docs. One line per change a reader
   will notice, task id kept, Conventional prefix removed. With
   changesets: `pnpm changeset status`, and every changed package needs a
   changeset (count).
5. Bump exactly the version fields: `VERSION`; `package.json` and
   `app.json`; `pyproject.toml`; Android `versionName` plus `versionCode`
   incremented; iOS `MARKETING_VERSION` plus the build number. `--package`
   also writes `docs/releases/<name>-<version>.md` from the checklist
   template.
6. Run the gate. Then print for the engineer, and nothing else runs:
   ```
   git add -A && git commit -m "chore(release): vX.Y.Z"      (<name>@X.Y.Z in a workspace)
   git tag -a vX.Y.Z -m "vX.Y.Z"                             (<name>@X.Y.Z in a workspace)
   git push origin <release branch> --follow-tags
   npm publish --access public --provenance                  (--package: pnpm changeset publish | uv publish | none for Go)
   ```
   and the `release/vX.Y.Z` branch step when CONTRIBUTING.md says so.
7. Print the output contract, then the changelog section and the gate
   tail.

## Output contract

```
## Release: <name> v<before> -> v<after> (<major|minor|patch>, <service|package>, branch <name>)
Commits since <tag>: N (feat a, fix b, changed c, unclassifiable u)
Surface: S -> T symbols; removed R, added A, changed C; semver from the diff: <bump> (commits: <bump>)   (package)
Pack: N files (findings: <list | none>)   README install: ok | written                            (package)
Order: <a>, <b>, <c>                                                                                (workspace)
Provenance: npm --provenance (CI OIDC) | PyPI trusted publisher | Go sum db | none (laptop publish) (package)
CHANGELOG: section added | file created | changesets N of N   Version file: <file> edited
Gate: make check: passed | <native command> (improvised): passed | not run
Commands for the engineer:
  <lines>
```

## Gotchas

- Never tags, pushes or publishes. `--dry-run` is the only pack flag the
  agent runs; the real commands are printed.
- A removed export is breaking even when nobody is thought to use it.
  The diff decides; a guess about consumers does not.
- A `.env` in a published tarball is unrecoverable: unpublish is limited
  and mirrors keep the file.
- Go: a major bump is a new module path (`/v2`); a `v2.0.0` tag without
  it is invisible to `go get`.
- Python: `__all__` is the surface only when it is defined; without it
  every public name counts.
- Publishing a dependent before its dependency leaves a window where the
  registry holds a package that cannot install.
- Provenance cannot come from a laptop; a signed claim without CI OIDC is
  false in the release notes.
- "Misc fixes" is not a changelog entry. A mobile release also needs
  store metadata: `app-store-release`.
