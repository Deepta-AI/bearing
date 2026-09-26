-- +goose NO TRANSACTION
-- +goose Up
CREATE INDEX CONCURRENTLY idx_invoice_lines_invoice ON invoice_lines (invoice_id);
-- +goose Down
DROP INDEX CONCURRENTLY IF EXISTS idx_invoice_lines_invoice;
