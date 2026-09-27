CREATE TABLE line_items (
  id BIGSERIAL PRIMARY KEY,
  invoice_id BIGINT NOT NULL REFERENCES invoices(id),
  unit_paise BIGINT NOT NULL,
  qty INT NOT NULL CHECK (qty > 0)
);
