-- +goose Up
CREATE TABLE accounts (
    id         bigserial PRIMARY KEY,
    name       text NOT NULL,
    api_key    text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE invoices (
    id           bigserial PRIMARY KEY,
    account_id   bigint NOT NULL REFERENCES accounts (id),
    number       text NOT NULL,
    amount_paise bigint NOT NULL CHECK (amount_paise > 0),
    status       text NOT NULL DEFAULT 'draft'
                 CHECK (status IN ('draft', 'open', 'paid')),
    due_on       date NOT NULL,
    created_at   timestamptz NOT NULL DEFAULT now(),
    UNIQUE (account_id, number)
);

-- The list endpoint filters by account and status, newest first.
CREATE INDEX invoices_account_status_created ON invoices (account_id, status, created_at DESC);

-- +goose Down
DROP TABLE invoices;
DROP TABLE accounts;
