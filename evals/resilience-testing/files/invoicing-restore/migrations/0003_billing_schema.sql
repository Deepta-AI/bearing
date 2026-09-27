-- Money moves to its own schema so finance can be granted read access to it alone.
CREATE SCHEMA billing;

CREATE TABLE billing.invoices (
    id           BIGSERIAL PRIMARY KEY,
    customer_id  BIGINT NOT NULL REFERENCES public.customers(id),
    number       TEXT NOT NULL UNIQUE,
    total_cents  BIGINT NOT NULL,
    issued_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE billing.payments (
    id           BIGSERIAL PRIMARY KEY,
    invoice_id   BIGINT NOT NULL REFERENCES billing.invoices(id),
    amount_cents BIGINT NOT NULL,
    received_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
