-- +goose Up
CREATE TABLE invoices (
    id           bigserial PRIMARY KEY,
    tenant_id    bigint NOT NULL REFERENCES tenants(id),
    customer_id  bigint NOT NULL REFERENCES customers(id),
    number       text NOT NULL,
    amount_paise bigint NOT NULL,
    status       text NOT NULL DEFAULT 'open',
    created_at   timestamptz NOT NULL DEFAULT now(),
    paid_at      timestamptz
);
CREATE UNIQUE INDEX idx_invoices_tenant_number ON invoices (tenant_id, number);

-- +goose Down
DROP TABLE invoices;
