CREATE TABLE chargebacks (
    id          bigserial PRIMARY KEY,
    payment_id  text NOT NULL REFERENCES payments (id),
    amount      bigint NOT NULL CHECK (amount > 0),
    reason_code text NOT NULL,
    opened_at   timestamptz NOT NULL DEFAULT now()
);
