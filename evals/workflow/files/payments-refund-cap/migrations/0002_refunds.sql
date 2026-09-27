CREATE TABLE refunds (
    id         bigserial PRIMARY KEY,
    payment_id text NOT NULL REFERENCES payments (id),
    amount     bigint NOT NULL CHECK (amount > 0),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX refunds_payment_id ON refunds (payment_id);
