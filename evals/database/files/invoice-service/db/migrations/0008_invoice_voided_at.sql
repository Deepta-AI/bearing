-- +goose Up
SET lock_timeout = '2s';
ALTER TABLE invoices ADD COLUMN voided_at timestamptz;
-- +goose Down
SET lock_timeout = '2s';
ALTER TABLE invoices DROP COLUMN voided_at;
