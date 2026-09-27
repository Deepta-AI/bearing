CREATE TABLE payouts (
    id          bigserial PRIMARY KEY,
    merchant_id text NOT NULL,
    amount      bigint NOT NULL CHECK (amount > 0),
    paid_at     timestamptz
);
