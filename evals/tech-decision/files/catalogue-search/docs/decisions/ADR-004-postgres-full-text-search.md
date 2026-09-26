# ADR-004: Postgres full-text search for product search

Status: Accepted (2025-07-02)

## Context
Product search needs to match names and descriptions. The catalogue had
40,000 products at launch.

## Decision
We will use Postgres full-text search: a generated tsvector column on
products with a GIN index, queried with websearch_to_tsquery.

## Alternatives considered
- Elasticsearch on EC2: rejected, a cluster to run for 40,000 rows.
- Algolia: rejected on cost at the time.

## Consequences
No extra service. No typo tolerance: a misspelt query matches nothing.
