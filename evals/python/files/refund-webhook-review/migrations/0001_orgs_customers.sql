CREATE TABLE orgs (
    id   TEXT PRIMARY KEY,
    name TEXT NOT NULL
);

CREATE TABLE api_keys (
    key_hash TEXT PRIMARY KEY,
    org_id   TEXT NOT NULL REFERENCES orgs (id)
);

CREATE TABLE customers (
    id         TEXT PRIMARY KEY,
    org_id     TEXT NOT NULL REFERENCES orgs (id),
    name       TEXT NOT NULL,
    email      TEXT NOT NULL,
    created_at TEXT NOT NULL
);

-- GET /customers pages by (created_at, id) within one org.
CREATE INDEX customers_org_created ON customers (org_id, created_at, id);
