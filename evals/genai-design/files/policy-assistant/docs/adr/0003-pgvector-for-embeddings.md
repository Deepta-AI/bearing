# 0003. Postgres with pgvector for embeddings

Status: Accepted (2026-04-22)

## Context
The document search in the intranet needed semantic search. The People
and IT teams run one Postgres 16 cluster already.

## Decision
We will store embeddings in Postgres with the pgvector extension. A
dedicated vector database needs a new ADR.

## Consequences
One datastore to back up and secure. Index size is fine for tens of
thousands of chunks.
