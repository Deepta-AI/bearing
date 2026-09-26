-- +goose Up
CREATE INDEX idx_invoices_tenant ON invoices (tenant_id);
CREATE INDEX idx_invoices_customer ON invoices (customer_id);
-- +goose Down
DROP INDEX idx_invoices_customer;
DROP INDEX idx_invoices_tenant;
