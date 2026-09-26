-- +goose Up
SET lock_timeout = '3s';
ALTER TABLE invoices ADD COLUMN due_at timestamptz;

-- +goose Down
SET lock_timeout = '3s';
ALTER TABLE invoices DROP COLUMN due_at;
