# 2. In-memory store until the Postgres port

Status: Accepted

## Context

The first clinics go live on a single instance while the schema settles.

## Decision

We will keep data in memory behind internal/store and port to Postgres
in a later story, keeping the same method signatures.

## Consequences

A restart loses data; acceptable for the pilot only.
