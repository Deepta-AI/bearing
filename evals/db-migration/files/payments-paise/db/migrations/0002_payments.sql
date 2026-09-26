-- +goose Up
CREATE TABLE payments (
    id          INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES customers(id),
    amount      REAL,
    created_at  TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
CREATE INDEX idx_payments_customer ON payments (customer_id);

-- +goose Down
DROP TABLE payments;
