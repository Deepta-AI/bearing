-- +goose NO TRANSACTION
-- +goose Up
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payment_events_invoice
    ON payment_events (invoice_id);

-- +goose Down
DROP INDEX CONCURRENTLY IF EXISTS idx_payment_events_invoice;
