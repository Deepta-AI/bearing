-- Coupon redemptions, one row per use of a code.
CREATE TABLE redemptions (
    id          bigserial PRIMARY KEY,
    customer_id text        NOT NULL,
    code        text        NOT NULL,
    redeemed_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX redemptions_customer_idx ON redemptions (customer_id);
