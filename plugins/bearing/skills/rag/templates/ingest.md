# Ingestion pipeline

One module, `rag/ingest.py` (Python) or `src/rag/ingest.ts` (TypeScript),
run by `make ingest CORPUS=<path>`. Re-running over an unchanged corpus
writes nothing and says so.

## Stages

```
discover -> parse -> chunk -> hash -> diff -> embed -> upsert -> sweep -> report
```

1. **discover**: walk the corpus (or pull from the source system). Emit
   `(source_uri, bytes, kind, mtime)`. Zero sources: exit 1 with
   "0 documents found".
2. **parse**: by kind. PDF through a layout-aware parser with page
   numbers; HTML to text with headings kept; markdown as is; code with
   tree-sitter; tables to rows with headers; images to a caption from
   `claude-sonnet-5` plus alt text. Parse failures are counted and
   logged with the uri, never swallowed.
3. **chunk**: per `references/chunking.md`. Each chunk carries `ord`,
   `span_start`, `span_end`, `text`, `embed_text`, `metadata`.
4. **hash**: `content_hash = sha256(parsed text)` per document and per
   chunk.
5. **diff**: look up `(tenant_id, source_uri, content_hash)`. Present:
   skip. Absent but the uri exists: new version. Absent entirely: new
   document.
6. **embed**: batches of 64 to 128 `embed_text` values through the
   embedding client from the ADR. Retry on 429 and 5xx with backoff.
   Truncation is an error to count, not silence.
7. **upsert**: one transaction per document. Insert the document row,
   insert its chunks, then flip `is_current`: the new version true, the
   old version false. Readers see one consistent version.
8. **sweep**: delete documents with `is_current = false` older than the
   retention window (default 7 days) in batches of 1,000, outside the
   ingest transaction.
9. **report**: print the contract below and write the same line to the
   structured log.

## Contract

```
ingest: <D> documents, <N> new, <U> updated, <S> skipped (unchanged), <F> failed
chunks: <C> written, p50 <n> tokens, p95 <n> tokens, <X> truncated, <Y> duplicates dropped
embedding: <model> (<dims>), <T> tokens, <cost> USD
```

## Rules

- Idempotent: the same input twice produces one set of rows. The test
  ingests a fixture twice and asserts row counts are equal.
- Versioned: a changed document never overwrites in place; citations
  in old answers still resolve to the version they cited.
- Tenant-scoped: `tenant_id` on every row from the start, even with one
  tenant today.
- Batched: embedding and inserts in batches; a 50K-chunk corpus is not
  50K round trips.
- Resumable: a crash mid-run leaves complete documents committed and
  the rest untouched; the next run skips what is done.
- Secrets and PII: a redaction pass before embedding when the corpus
  can contain them (tickets, chat, emails). The pass is a named
  function with a test.

## Tests

- `test_ingest_twice_is_idempotent`
- `test_changed_document_creates_new_version_and_hides_old`
- `test_parse_failure_is_counted_not_raised`
- `test_zero_documents_fails`
- `test_chunk_metadata_present` (title, section, tenant on every chunk)
