-- +goose Up
CREATE INDEX idx_payments_created ON payments (created_at);

-- +goose Down
DROP INDEX idx_payments_created;
