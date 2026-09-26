-- +goose NO TRANSACTION
-- +goose Up
-- Serves the monthly export (InvoiceRepo.export_created_between).
CREATE INDEX CONCURRENTLY idx_invoices_tenant_created ON invoices (tenant_id, created_at);
-- +goose Down
DROP INDEX CONCURRENTLY IF EXISTS idx_invoices_tenant_created;
