# Pattern: search

Start with the database you have. Postgres full text covers most
products until relevance tuning, typo tolerance or faceting across
millions of rows demand a search engine. Whichever engine, the index is
rebuilt from the source of truth, never the other way round.

Markers: `tsvector|to_tsquery|websearch_to_tsquery|pg_trgm|opensearch|elasticsearch|typesense|meilisearch|reindex`
Decision keys (ADR grep): `search`, `full text`, `opensearch`, `typesense`

## Decision questions

1. Engine: Postgres full text, Typesense or Meilisearch, or OpenSearch?
   Recommend Postgres (`tsvector` plus `pg_trgm`) under 1 million rows
   with no faceting; Typesense for typo tolerance, facets and instant
   results with one operator; OpenSearch when aggregations, multiple
   languages or over 50 million documents are real requirements.
2. Indexing: synchronous in the write transaction, or an outbox with a
   worker? Recommend the outbox: writes never wait on the engine, and a
   rebuild is the same code path.
3. Freshness: seconds or minutes? Sets the outbox poll interval and the
   UI copy ("results may take a minute").
4. What is searched and what is filtered? Text fields ranked; ids,
   tenant, status and dates filtered before ranking, never ranked.
5. Relevance judged by whom? Recommend a golden query set from the
   product owner (20 queries with the expected top result) as a test.
6. Tenant isolation: a filter on every query, enforced in one place.

## Data model

Postgres:

```
alter table items add column search tsvector generated always as
  (setweight(to_tsvector('simple', coalesce(title,'')), 'A') ||
   setweight(to_tsvector('simple', coalesce(body,'')), 'B')) stored;
create index items_search_idx on items using gin (search);
create index items_title_trgm on items using gin (title gin_trgm_ops);
```

Engine:

```
search_outbox(id, entity, entity_id, op[upsert|delete], created_at, processed_at)
index schema: id, tenant_id (filter), title (text, weight 3), body (text), status (facet),
              created_at (sort), plus the display fields so hits need no join
```

## Flow

1. Write path inserts into the entity and `search_outbox` in one transaction.
2. Worker drains the outbox in batches, upserts into the index, marks processed.
3. Query: `websearch_to_tsquery('simple', q)` ranked with `ts_rank_cd`, prefix
   fallback with `similarity()` on the title; engine: one query with
   `filter_by: tenant_id:=<id>`, `query_by: title,body`, facets on status.
4. Rebuild: `reindex` walks the source table into the outbox; the old index
   is swapped by alias after the walk completes.

## Failure modes

| Fault | Handling |
| --- | --- |
| engine down | write path unaffected (outbox); search returns 503 with a retry hint, or falls back to `ILIKE` on the title |
| outbox lag | age of the oldest unprocessed row is a metric with an alert at 5 minutes |
| partial rebuild | build into a new index, swap the alias only when counts match the source |
| tenant leak | the filter is added by the search module, not by callers; a test asserts it |
| stemming surprises (`simple` vs `english`) | choose per language column; document the config |
| query injection into `to_tsquery` | always `websearch_to_tsquery` or `plainto_tsquery` |

## Tests to write

- golden set: each of the 20 queries returns its expected document in the top 3
- a document written then searched within the freshness window is found
- a deleted document disappears from results after the outbox drains
- tenant A's query never returns tenant B's document (both indexed)
- a typo (`invoce`) finds `invoice` on the engine path; the Postgres path documents its limit
- outbox lag metric rises when the worker is stopped and the alert fires in the test harness
- rebuild swaps the alias only when the count matches

## Per-stack pointers

- Go: `pgx` with the generated column; `typesense-go`; `opensearch-go`.
- Python: SQLAlchemy `func.websearch_to_tsquery`; `typesense` client; `opensearch-py`.
- React: debounce 250 ms, cancel in-flight with `AbortController`, show the
  applied filters as chips; never search on every keystroke without both.
- Mobile: search on submit or after 300 ms idle; offline shows the last results with a banner.
