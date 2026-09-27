CREATE TABLE invoices (
    invoice_id  TEXT PRIMARY KEY,
    customer_id TEXT NOT NULL,
    amount_minor BIGINT NOT NULL,
    issued_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
