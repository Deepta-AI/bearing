CREATE TABLE customers (
    id          BIGSERIAL PRIMARY KEY,
    name        TEXT NOT NULL,
    tax_id      TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
