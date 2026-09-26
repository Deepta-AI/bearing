-- +goose Up
SET lock_timeout = '3s';
ALTER TABLE tenants ADD COLUMN plan text NOT NULL DEFAULT 'standard';

-- +goose Down
SET lock_timeout = '3s';
ALTER TABLE tenants DROP COLUMN plan;
