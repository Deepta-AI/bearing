---
name: rag
description: 'Builds retrieval-augmented generation (RAG) on pgvector: ingestion, chunking, embeddings, a retriever with citations, retrieval metrics. Use when asked to "add RAG", "chat with our documents" or "chunk and embed".'
argument-hint: "<naive|hybrid|reranked|hierarchical|graph|agentic|sql|multimodal|long-context> <name> [--corpus <path>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(wc -l:*), Bash(make:*), Bash(git status:*), Bash(uv run:*), Bash(npm run:*)
---

# rag

Retrieval is a search problem with a model at the end. The type is chosen
from the corpus and the questions, not from fashion. Every RAG this skill
builds is measured on a golden set before anyone calls it done.

## Inputs

- Solution doc: `docs/genai/<name>-solution.md`; if absent, asks the
  task, the scale (queries per day, corpus size) and the model tier in
  one question and continues.
- Corpus: `--corpus` or the path the user names; if neither, looks for
  `docs/`, `data/` or fixtures in the code and asks the user to confirm
  the path. Still no documents: stop with "give a path holding at least
  one document to ingest".
- Database: `DATABASE_URL` and a migrations folder; if absent, the schema
  is written to `migrations/<name>_rag.sql` for the user to apply, and
  pgvector is listed as a requirement.
- Gateway: `llm/` from `llm-gateway`; if absent, the retriever and
  the answer step call the SDK through one function; gateway follow-up.
- Golden set: `evals/<name>/retrieval.jsonl`; if absent, step 8 seeds
  ten questions from the corpus owner or the corpus and marks them
  `seed`; the 30-question set comes from `llm-eval`.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys
vector store and embeddings. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Type from `$1`, name from `$2`. Read `references/rag-types.md` and
   check the choice against the corpus size, the question shape and the
   cost profile. If `long-context` fits (corpus under 150K tokens, few
   queries per day), say so and offer it even when another type was
   asked for. A type without a stated reason is a finding.
2. Corpus: `--corpus` or the path the user names. Count documents by
   kind (pdf, html, markdown, code, tables, images). Zero documents:
   the Inputs fallback, then stop naming the path to provide. Pick chunking per kind
   from `references/chunking.md` and write the parameters in the
   ingestion module header.
3. Embedding ADR (`adr`, or a file in `docs/adr/` in that shape).
   Anthropic has no embedding endpoint; the options are Voyage AI (Anthropic's
   recommended partner, hosted, per-token cost) or an open model served
   locally (bge-m3, multilingual-e5-large, no per-call cost, needs a
   GPU or patience). Record model id, dimensions, max input tokens,
   whether queries and documents use different prefixes, and the cost
   per million tokens. Changing the model later means re-embedding
   everything; the ADR says so.
4. Schema from `templates/schema.sql`: `documents` with `version` and
   `content_hash`, `chunks` with span offsets, a `vector(<dims>)` column,
   a generated `tsvector` for hybrid, and an HNSW index with `m` and
   `ef_construction` stated. Apply with `db-migration <name>_rag`, else the repo's
   migration tool, else hand the SQL file to the user.
   Qdrant only when an ADR shows pgvector cannot hold the load (over
   about 10M vectors or p95 recall latency past the SLO after tuning).
5. Ingestion from `templates/ingest.md`: parse, split, embed in batches,
   upsert keyed by `(source_uri, content_hash)`. A re-run over an
   unchanged corpus writes zero rows. A changed document gets a new
   version; the old chunks are hidden from retrieval, then deleted by a
   job. Metadata (title, section, page, tenant, updated_at) travels
   with every chunk. `make ingest` runs it when a Makefile exists, else
   the native command (`uv run python -m <pkg>.ingest` or `npm run
   ingest`); log documents, chunks, skipped, failed.
6. Retrieval API from `templates/retriever.md`: `retrieve(query, k,
   filters) -> [Hit]`, every `Hit` carrying `document_id`, `chunk_id`,
   `span`, `score`, `source_uri`. Hybrid fuses BM25 and vector ranks
   with reciprocal rank fusion (`k=60`); reranked adds a cross-encoder
   or a `claude-haiku-4-5` pointwise judge over the top 20; agentic
   plans sub-queries with `claude-opus-5` and loops at most 3 times;
   sql validates every generated statement (read-only role, allow-listed
   tables, `EXPLAIN` before run). Metrics: `rag_retrieval_duration_seconds`
   and `rag_empty_results_total` through the meter `observability`
   wired, else one created in the retriever module.
7. Generation: the answer prompt cites `[doc:chunk]` per claim and
   answers "not in the documents" when the hits are empty or below the
   score floor. Set the floor from the golden set: print the top score
   of every answerable and every unanswerable question and pick the
   value that separates them. When no value does, say so, leave the
   floor off, and let a deterministic check reject an answer that cites
   no hit or a chunk it was not given. The prompt text is versioned with `prompt-registry` when a
   registry exists, else written to `prompts/<name>/v1.md`.
   Retrieved text is untrusted input: strip instructions, wrap it in a
   `<documents>` block; the injection tests are an `llm-guardrails`
   follow-up. Model calls go through the gateway when present.
8. Golden set: at least 30 questions from real users or the corpus
   owner, each with the chunk ids that answer it, in
   `evals/<name>/retrieval.jsonl` from `templates/eval-set.jsonl`;
   fewer than 30 is a `seed` set and the report says so.
   Compute recall@5, recall@10 and MRR per `references/retrieval-eval.md`
   with `make eval-retrieval`, else the eval script directly. Answer
   faithfulness and relevance are `llm-eval <name>`'s job. The
   numbers are reported, never assumed.
9. Report in the AGENTS.md shape.

## Output contract

```
## RAG: <name> (<type>)
corpus: <D> documents, <C> chunks, <S> skipped (unchanged), <F> failed
embedding: <model> (<dims> dims), ADR docs/adr/NNNN-...
schema: migrations/<file>, index hnsw(m=<m>, ef_construction=<ef>)
retriever: <path>, citations: document_id, chunk_id, span
golden set: evals/<name>/retrieval.jsonl (<Q> questions)
recall@5: <x.xx>  recall@10: <x.xx>  MRR: <x.xx>
handed off: prompt-registry, llm-guardrails, llm-eval <name>
```

## Gotchas

- Recall below 0.8 at k=10 is a chunking or embedding problem, not a
  prompt problem. Fix retrieval before touching the generation prompt.
- A chunk without its heading loses its meaning. Prepend the title and
  section path to the text that is embedded.
- HNSW `ef_search` is a session setting. Set it in the repository code,
  not once by hand in psql.
- pgvector indexes `vector` up to 2000 dimensions. Larger embeddings use
  `halfvec` or are truncated (Matryoshka models allow it); say which.
- Postgres `ts_rank_cd` is not BM25. It is close enough for hybrid with
  RRF; true BM25 needs `pg_search` and its own ADR.
- Documents in the index that the caller may not read leak through
  citations. Filter by tenant and ACL inside the query, never after.
- Never embed secrets or PII; the vector is reversible enough to matter.
- A document kept out of the model's input (confidential, superseded,
  draft) is tested by content: assert that a distinctive figure or
  sentence from its body is absent from the assembled input. A title or
  path check passes while a copied paragraph leaks.
- An exact identifier (error code, SKU, clause number) must bring back
  the chunk that defines it at rank 1, above chunks that only mention
  it. Put one such question per identifier family in the golden set and
  assert the rank in a test; boost an exact identifier match rather
  than trusting rank fusion to keep it on top.
