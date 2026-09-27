---
name: release
description: 'Prepares a release from main: next version from the latest tag, changelog, release branch and the printed commands to publish it. Use when asked to "cut a release", "prepare v1.4" or "what goes in this release".'
argument-hint: "[major|minor|patch]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(git log:*), Bash(git tag --list:*), Bash(git describe:*), Bash(git checkout -b:*), Bash(git commit:*), Bash(make check:*)
---

# release

Cuts a release from main. The developer publishes it; this skill prepares
everything up to that point and prints the commands.

Not this: a fix shipped on top of an older release tag while main has
moved on (no skill yet).

## Inputs

- Bump: `$1`; if absent, from the commit types since the last tag
  (`feat` is minor, `fix` is patch, `!` is major).
- Current version: the latest `vX.Y.Z` tag (`git describe --tags
  --abbrev=0`). The version lives in tags only; a VERSION or
  package.json version is updated only when the repository already keeps
  one, and the tag wins when they disagree.
- Changelog: `CHANGELOG.md`; if absent, created with an Unreleased
  section.

## Steps

1. Read the tags and the log since the latest tag.
2. Work out the next version and move Unreleased into it in the
   changelog.
3. `git checkout -b release/vX.Y.Z` and commit the changelog.
4. Run `make check`; stop if it fails and say which gate.
5. Print, never run: `git push origin release/vX.Y.Z`, the tag command
   and the push of the tag (ADR-0001).

## Output contract

```
Release: vX.Y.Z (from vA.B.C, N commits: F feat, X fix)
Branch: release/vX.Y.Z   make check: passed | failed (<gate>)
Run these yourself:
  <commands>
```

## Gotchas

- A tag that is not on main (a hotfix tag) is still the latest version;
  compare with `git tag --merged main` and say when they differ.
- Never tag locally on the developer's behalf; a local tag gets pushed by
  accident with `--tags`.
