-- +goose Up
UPDATE payments SET method = 'card' WHERE method IS NULL;

-- +goose Down
SELECT 1;
