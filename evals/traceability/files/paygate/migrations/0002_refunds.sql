CREATE TABLE refunds (
    id          TEXT PRIMARY KEY,
    payment_id  TEXT NOT NULL REFERENCES payments(id),
    idem_key    TEXT NOT NULL UNIQUE,
    amount      BIGINT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE payments ADD COLUMN refunded BIGINT NOT NULL DEFAULT 0;
