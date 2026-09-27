# ADR-0002: Agent tooling is pinned and comes from the internal mirror

Status: Accepted

## Context

Build hosts and most laptops on the claims network have no internet access.
Skill packs are text that the agent follows with this repository's
permissions, so a change to a pack is a change to what can run here.

## Decision

- Every piece of agent tooling (the team kit marketplace, gstack, third-party
  skill packs) is pinned by commit in `.claude/tooling.lock` and cloned from
  `.mirror/` by `make bootstrap`. Nothing is installed from the internet.
- Moving a pin is a merge request that changes the lock. For a third-party
  skill pack, the merge request lists every new `allowed-tools` entry, hook
  and network call in the upstream diff. A pack version that adds shell
  access beyond what it had, or any download or network call, needs security
  sign-off before its pin moves.
- Local changes to a vendored pack are kept as patches in `.claude/patches/`,
  named `<source>-<what>.patch`, and `make bootstrap` applies them. Nobody
  edits a vendored checkout by hand.
- `tools/team-kit` is also the working checkout for changes to the team kit
  itself: kit changes are made there and sent to the kit repository.

## Consequences

A teammate gets new tooling only through the lock. Updating a checkout
without the lock is undone by the next `make bootstrap`.
