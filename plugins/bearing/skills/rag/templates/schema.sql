-- RAG schema for <name>. Apply through db-migration; keep the header
-- block from skills/db-migration/templates/HEADER.sql above this.
-- Index decision: hnsw on chunks.embedding serves the vector query;
-- gin on chunks.tsv serves the BM25 leg; btree on (tenant_id, document_id)
-- serves the ACL filter that runs inside every retrieval query.

CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE rag_documents (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id     uuid NOT NULL,
    source_uri    text NOT NULL,
    version       integer NOT NULL DEFAULT 1,
    content_hash  text NOT NULL,
    title         text NOT NULL,
    kind          text NOT NULL,           -- pdf | html | markdown | code | table | image
    metadata      jsonb NOT NULL DEFAULT '{}'::jsonb,
    is_current    boolean NOT NULL DEFAULT true,
    ingested_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (tenant_id, source_uri, content_hash)
);

-- One current version per source. Old versions stay until the sweeper
-- deletes them; retrieval filters on is_current.
CREATE UNIQUE INDEX rag_documents_current_idx
    ON rag_documents (tenant_id, source_uri) WHERE is_current;

CREATE TABLE rag_chunks (
    id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id   uuid NOT NULL REFERENCES rag_documents (id) ON DELETE CASCADE,
    tenant_id     uuid NOT NULL,
    parent_id     uuid REFERENCES rag_chunks (id),   -- hierarchical only
    ord           integer NOT NULL,
    span_start    integer NOT NULL,                  -- char offset in the source
    span_end      integer NOT NULL,
    text          text NOT NULL,                     -- raw span, quoted in citations
    embed_text    text NOT NULL,                     -- title > section + text, what was embedded
    content_hash  text NOT NULL,
    metadata      jsonb NOT NULL DEFAULT '{}'::jsonb, -- section, page, language
    embedding     vector(1024) NOT NULL,             -- dims from the embedding ADR
    tsv           tsvector GENERATED ALWAYS AS (to_tsvector('english', embed_text)) STORED,
    created_at    timestamptz NOT NULL DEFAULT now(),
    UNIQUE (document_id, ord)
);

-- ACL and version filter, applied inside every retrieval query.
CREATE INDEX rag_chunks_tenant_doc_idx ON rag_chunks (tenant_id, document_id);

-- Vector leg. m=16, ef_construction=64 are the pgvector defaults and
-- hold to a few million rows; raise m to 24 and ef_construction to 128
-- when recall@10 on the golden set is short and the miss is in the ANN
-- (check by comparing with an exact scan on a sample). Build the index
-- after the first bulk load, not before; set maintenance_work_mem high
-- for the build. ef_search is set per session by the repository
-- (SET LOCAL hnsw.ef_search = 100).
CREATE INDEX rag_chunks_embedding_idx
    ON rag_chunks USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Lexical leg for hybrid.
CREATE INDEX rag_chunks_tsv_idx ON rag_chunks USING gin (tsv);

-- Graph type only: entities and relations extracted at ingest.
-- CREATE TABLE rag_entities (id uuid PRIMARY KEY, tenant_id uuid NOT NULL,
--     name text NOT NULL, kind text NOT NULL, chunk_id uuid REFERENCES rag_chunks (id));
-- CREATE TABLE rag_relations (subject_id uuid REFERENCES rag_entities (id),
--     predicate text NOT NULL, object_id uuid REFERENCES rag_entities (id),
--     chunk_id uuid REFERENCES rag_chunks (id), PRIMARY KEY (subject_id, predicate, object_id));

-- Retrieval log for the metrics and the empty-results alert.
CREATE TABLE rag_queries (
    id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id      uuid NOT NULL,
    query_hash     text NOT NULL,       -- never the query text by default
    hits           integer NOT NULL,
    top_score      real,
    duration_ms    integer NOT NULL,
    created_at     timestamptz NOT NULL DEFAULT now()
);

-- Down:
-- DROP TABLE rag_queries; DROP TABLE rag_chunks; DROP TABLE rag_documents;
