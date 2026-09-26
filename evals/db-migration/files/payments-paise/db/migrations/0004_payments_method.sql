-- +goose Up
ALTER TABLE payments ADD COLUMN method TEXT;

-- +goose Down
ALTER TABLE payments DROP COLUMN method;
