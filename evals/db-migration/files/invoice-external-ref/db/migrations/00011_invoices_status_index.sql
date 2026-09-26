-- +goose NO TRANSACTION
-- +goose Up
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_invoices_tenant_status
    ON invoices (tenant_id, status);

-- +goose Down
DROP INDEX CONCURRENTLY IF EXISTS idx_invoices_tenant_status;
