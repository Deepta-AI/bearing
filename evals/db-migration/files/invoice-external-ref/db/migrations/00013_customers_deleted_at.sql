-- +goose Up
SET lock_timeout = '3s';
ALTER TABLE customers ADD COLUMN deleted_at timestamptz;

-- +goose Down
SET lock_timeout = '3s';
ALTER TABLE customers DROP COLUMN deleted_at;
