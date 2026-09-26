# 0003. Resolve Go modules from a mirror snapshot

Status: Accepted (2026-03-02)

## Context

The build hosts and CI runners in the billing network have no internet
access. Builds must be reproducible from what is on the host.

## Decision

All modules resolve from `third_party/goproxy`, a GOPROXY-format snapshot
the platform team syncs weekly. The Go vulnerability database is mirrored
alongside it in `third_party/vulndb` on the same schedule; its
`index/db.json` records when it was last synced. A version that is not in
the mirror cannot be used until the next sync.

## Consequences

Upgrades can only move to versions present in the mirror. A vulnerability
scan is as current as the last vulndb sync.
