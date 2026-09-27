-- +goose Up
CREATE TABLE accounts (
    id         text PRIMARY KEY,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE accounts;
