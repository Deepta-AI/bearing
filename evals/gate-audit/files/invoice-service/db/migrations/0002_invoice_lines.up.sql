CREATE TABLE invoice_lines (
    id          BIGSERIAL PRIMARY KEY,
    invoice_id  TEXT NOT NULL REFERENCES invoices(invoice_id),
    description TEXT NOT NULL,
    unit_minor  BIGINT NOT NULL,
    quantity    INT NOT NULL DEFAULT 1
);
