-- +goose Up
CREATE TABLE customers (
    id    INTEGER PRIMARY KEY,
    email TEXT NOT NULL UNIQUE
);

-- +goose Down
DROP TABLE customers;
