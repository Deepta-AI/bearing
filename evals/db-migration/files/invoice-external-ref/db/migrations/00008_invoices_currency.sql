-- +goose Up
SET lock_timeout = '3s';
ALTER TABLE invoices ADD COLUMN currency text NOT NULL DEFAULT 'INR';

-- +goose Down
SET lock_timeout = '3s';
ALTER TABLE invoices DROP COLUMN currency;
