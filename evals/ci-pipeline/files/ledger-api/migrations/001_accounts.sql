CREATE TABLE IF NOT EXISTS accounts (
    name text PRIMARY KEY
);

CREATE TABLE IF NOT EXISTS postings (
    id bigserial PRIMARY KEY,
    reference text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS posting_lines (
    posting_id bigint NOT NULL REFERENCES postings (id),
    account text NOT NULL REFERENCES accounts (name),
    amount bigint NOT NULL
);
