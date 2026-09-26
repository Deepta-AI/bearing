-- +goose Up
CREATE INDEX idx_invoices_status ON invoices (status);
-- +goose Down
DROP INDEX idx_invoices_status;
