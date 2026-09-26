-- +goose Up
CREATE TABLE invoice_lines (
    id          bigserial PRIMARY KEY,
    invoice_id  bigint NOT NULL REFERENCES invoices(id),
    description text NOT NULL,
    amount_paise bigint NOT NULL
);
CREATE INDEX idx_invoice_lines_invoice ON invoice_lines (invoice_id);

-- +goose Down
DROP TABLE invoice_lines;
