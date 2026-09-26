# Release checklist: <name> <old> -> <new>

<!-- Template guidance: the record of one package release (a library, SDK
     or CLI others install), written to docs/releases/<name>-<version>.md.
     The engineer who tags and publishes works down it; the agent never
     tags, pushes or publishes. Every comment says what goes there (What),
     what a strong entry has (Good) and an example (Example). Delete each
     comment when you fill its section. -->

Prepared: <YYYY-MM-DD>   Ecosystem: npm | go | python   Registry: <url | public>
Ticket: <TASK-ID> | none

## Surface diff (<tool> | manual)

<!-- What: every exported symbol removed, added or changed since the last
     tag, from the API diff tool (or manual), and the bump it implies.
     Good: removed or changed is major (minor while 0.x), only added is
     minor, none is patch; the diff wins over the commits and the line says
     when they disagree. A removed export is breaking even if nobody is
     thought to use it.
     Example: "changed | `Client.Upload` | method | major (new ctx
     argument)" -->

| Change | Symbol | Kind | Semver effect |
| --- | --- | --- | --- |
| removed | `<name>` | function | major |
| added | `<name>` | type | minor |

Symbols before: <S>   after: <T>   Bump: <major | minor | patch> (commits said <bump>)

## Checklist

<!-- What: the checks between the version bump and a working install.
     Good: tick only what was checked in this run; the pack line carries the
     real file count, and an unticked item says why. A .env in the tarball
     is unrecoverable, so the pack review is never skipped.
     Example: "- [x] Pack file list reviewed (42 files; no secrets, no tests,
     LICENSE and README present)" -->

- [ ] Surface diff read and the bump agreed
- [ ] Breaking changes each have a migration line in the changelog
- [ ] Pack file list reviewed (<N> files; no secrets, no tests, LICENSE and README present)
- [ ] README install snippet names `<name>` and the new version
- [ ] Changelog section `## [<new>] - <date>` written (or changesets cover every package)
- [ ] Dependents bumped in order: <a>, <b>, <c> (workspace only)
- [ ] Gate passed (`make check` | <native command>)
- [ ] Provenance path known: <npm --provenance | trusted publisher | sum db | none>
- [ ] Tag and publish commands printed below; engineer runs them
- [ ] Post-publish: `npm view <name> version` (or the registry page) shows <new>

## Commands (engineer runs; never run by the agent)

<!-- What: the commit, tag and publish commands, in order, for the engineer.
     Good: names and versions filled in; in a workspace, one block per
     package in dependency order; the publish line carries provenance only
     when CI OIDC exists, since a laptop publish cannot sign.
     Example: "pnpm changeset publish (from CI, npm --provenance via OIDC)" -->

```
git add -A && git commit -m "chore(release): <name>@<new>"
git tag -a <name>@<new> -m "<name>@<new>"
<publish command>
```

## Rollback

<!-- What: how to withdraw this version from the ecosystems that apply.
     Good: keep only the lines for this package's ecosystem, with the name
     and version filled in and the reason the consumer will see.
     Example: "npm deprecate @example/upload@3.0.0 \"breaks Node 18; use
     3.0.1\"" -->

- npm: `npm deprecate <name>@<new> "<reason>"` (unpublish only within 72 h and only when nothing depends on it)
- Go: retract the version in `go.mod` (`retract v<new>`) and tag a new patch
- Python: yank on the index (`uv publish` has no yank; use the index UI)
