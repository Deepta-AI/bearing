-- +goose Up
CREATE TABLE payments (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  invoice_id   bigint NOT NULL REFERENCES invoices (id),
  amount_minor bigint NOT NULL,
  received_at  timestamptz NOT NULL
);
CREATE INDEX idx_payments_invoice ON payments (invoice_id);
-- +goose Down
DROP TABLE payments;
