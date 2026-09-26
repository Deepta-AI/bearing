-- +goose Up
SET lock_timeout = '3s';
ALTER TABLE invoices ADD COLUMN pdf_key text;

-- +goose Down
SET lock_timeout = '3s';
ALTER TABLE invoices DROP COLUMN pdf_key;
