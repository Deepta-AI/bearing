CREATE TABLE accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE api_keys (
  key_hash TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id)
);

CREATE TABLE customers (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES accounts(id),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  created_at TEXT NOT NULL,
  deleted_at TEXT
);

-- Lists filter by account and page newest first.
CREATE INDEX customers_account_created ON customers (account_id, created_at DESC, id DESC);
