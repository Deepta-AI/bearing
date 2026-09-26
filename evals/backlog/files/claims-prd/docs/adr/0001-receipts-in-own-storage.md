# ADR-0001: Receipts stay in our own object storage

Status: Accepted, 2026-06-10

## Context
Receipts carry personal data (names, card digits, sometimes addresses). The
data protection review asked that they stay in India and under our control.

## Decision
Receipts are uploaded to our own bucket in the Mumbai region and served
through short-lived signed URLs. We do not link to or fetch from
third-party file storage.

## Consequences
Upload size drives storage cost; the 10 MB limit is set with that in mind.
