-- +goose Up
CREATE TABLE invoices (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id   bigint NOT NULL REFERENCES tenants (id),
  customer_id bigint NOT NULL REFERENCES customers (id),
  number      bigint NOT NULL,
  status      text NOT NULL DEFAULT 'draft'
              CHECK (status IN ('draft', 'sent', 'paid', 'void')),
  total_minor bigint NOT NULL,
  currency    char(3) NOT NULL,
  issued_at   timestamptz,          -- set when the invoice leaves draft; NULL for drafts
  created_at  timestamptz NOT NULL DEFAULT now(),
  deleted_at  timestamptz
);
-- +goose Down
DROP TABLE invoices;
