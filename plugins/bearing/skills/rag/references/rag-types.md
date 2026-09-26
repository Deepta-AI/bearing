# RAG types: when, failure modes, cost

Pick the simplest type whose failure modes the corpus does not trigger.
Start at naive or long-context; move up only with a measured gap on the
golden set.

| Type | Use when | Fails when | Cost profile |
| --- | --- | --- | --- |
| `long-context` | corpus under about 150K tokens, few queries per day, freshness not an issue | corpus grows, per-query cost is the whole corpus, latency past a few seconds | no infra; every call pays the corpus; prompt caching cuts it to about a tenth on repeat calls |
| `naive` | homogeneous prose, questions answered by one passage, first version | exact terms (ids, part numbers, names) the embedding blurs; multi-hop questions | one embedding per chunk once, one per query; pgvector only |
| `hybrid` | corpus with codes, names, jargon, or mixed languages | rank fusion hides a strong lexical hit behind weak vector hits when weights are untuned | naive plus a `tsvector` column and one more query; negligible |
| `reranked` | top 20 usually contain the answer but the top 5 do not | reranker latency (50 to 300 ms per query) on a tight SLO; reranker trained on a different domain | hybrid plus a cross-encoder call or a `claude-haiku-4-5` judge over 20 candidates |
| `hierarchical` | long documents where a chunk needs its surrounding section; legal, manuals, contracts | parent chunks blow the context budget; the same parent returned five times | storage roughly doubles (child and parent); retrieval cost as hybrid |
| `graph` | multi-hop questions over entities and relations ("who approved the vendor that supplied X") | entity extraction errors compound; the graph goes stale when documents change | extraction pass with `claude-sonnet-5` over every document at ingest; a relations table in Postgres |
| `agentic` | questions that need planning, several lookups, or a tool (search, SQL, calendar) | loops that never converge; cost per question 5 to 20 times naive; harder to evaluate | `claude-opus-5` for planning, cheaper model for sub-queries; cap the iterations |
| `sql` | questions answerable from a relational schema ("how many orders in March") | hallucinated columns; unbounded scans; writes | one model call per question plus one query; schema summary is cached |
| `multimodal` | images, diagrams, tables with meaning outside the text | captions lose numbers; table cells split across chunks | a captioning pass with `claude-sonnet-5` at ingest; chunks carry the image reference |

## Decision order

1. Count tokens in the corpus. Under 150K and under a few hundred
   queries a day: `long-context` with prompt caching, no index.
2. Otherwise start `hybrid`. It costs almost nothing over naive and
   removes the most common failure (exact terms).
3. Build the golden set. Measure recall@10.
4. Below 0.8: inspect the misses. Wrong chunk boundaries: fix chunking.
   Answer in the top 20 but not the top 5: add `reranked`. Answer needs
   the surrounding section: `hierarchical`. Answer needs two documents
   joined by an entity: `graph`. Answer needs a tool or several steps:
   `agentic`.
5. Structured questions over tables: `sql`, never a vector index over
   rows rendered as text.

## Long-context notes

- Put the corpus in the system prompt behind a `cache_control`
  breakpoint. Cache reads cost about a tenth of input; writes 1.25x.
- Cache TTL is 5 minutes by default. A corpus queried every hour pays a
  cache write per query and gains nothing; the type still holds when
  the corpus is small, it just costs full price.
- Use `claude-opus-5` with `thinking: {type: "adaptive"}` (omit the
  parameter; it is on by default). Sonnet 5 when the questions are
  lookups rather than synthesis. Both have a 1M context window.

## SQL notes

- The model sees a schema summary (tables, columns, types, one sample
  row, foreign keys), not the whole DDL.
- Every statement runs as a read-only role with `statement_timeout`
  and a row limit. The validator rejects anything that is not a single
  `SELECT`, references a table outside the allow-list, or has no
  `LIMIT`.
- `EXPLAIN` first; reject plans with a sequential scan over a table
  past 1M rows.
- The answer cites the query, not a chunk.

## Agentic notes

- The planner returns sub-queries as structured output (`output_config`
  with a JSON schema), never free text parsed with regex.
- At most 3 iterations; each iteration logs its sub-queries and hit
  counts under the same trace id.
- Retrieved text never becomes an instruction to the planner. Wrap it
  in `<documents>` and say so in the system prompt.
