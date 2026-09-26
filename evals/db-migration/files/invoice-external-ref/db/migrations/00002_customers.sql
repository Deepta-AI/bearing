-- +goose Up
CREATE TABLE customers (
    id         bigserial PRIMARY KEY,
    tenant_id  bigint NOT NULL REFERENCES tenants(id),
    email      text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_customers_tenant ON customers (tenant_id);

-- +goose Down
DROP TABLE customers;
