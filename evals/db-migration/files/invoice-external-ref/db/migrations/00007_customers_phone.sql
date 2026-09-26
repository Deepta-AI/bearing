-- +goose Up
SET lock_timeout = '3s';
ALTER TABLE customers ADD COLUMN phone text;

-- +goose Down
SET lock_timeout = '3s';
ALTER TABLE customers DROP COLUMN phone;
