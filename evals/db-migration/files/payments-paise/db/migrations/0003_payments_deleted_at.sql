-- +goose Up
ALTER TABLE payments ADD COLUMN deleted_at TEXT;

-- +goose Down
ALTER TABLE payments DROP COLUMN deleted_at;
