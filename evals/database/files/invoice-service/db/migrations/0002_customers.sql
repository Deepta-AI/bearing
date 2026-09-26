-- +goose Up
CREATE TABLE customers (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id  bigint NOT NULL REFERENCES tenants (id),
  name       text NOT NULL,
  email      text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX customers_tenant_email_key ON customers (tenant_id, lower(email));
-- +goose Down
DROP TABLE customers;
