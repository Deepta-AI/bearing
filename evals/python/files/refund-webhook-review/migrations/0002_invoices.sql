CREATE TABLE invoices (
    id                    TEXT PRIMARY KEY,
    org_id                TEXT NOT NULL REFERENCES orgs (id),
    customer_id           TEXT NOT NULL REFERENCES customers (id),
    number                TEXT NOT NULL,
    status                TEXT NOT NULL CHECK (status IN ('draft', 'open', 'paid', 'void')),
    currency              TEXT NOT NULL,
    amount_minor          INTEGER NOT NULL CHECK (amount_minor >= 0),
    amount_paid_minor     INTEGER NOT NULL DEFAULT 0,
    amount_refunded_minor INTEGER NOT NULL DEFAULT 0,
    -- NULL while the invoice is a draft; set when it is issued.
    issued_at             TEXT,
    created_at            TEXT NOT NULL,
    -- Invoice numbers are per organisation (INV-0001 exists in many orgs).
    UNIQUE (org_id, number)
);
