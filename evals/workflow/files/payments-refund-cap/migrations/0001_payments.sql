CREATE TABLE payments (
    id          text PRIMARY KEY,
    merchant_id text NOT NULL,
    captured    bigint NOT NULL CHECK (captured > 0),
    created_at  timestamptz NOT NULL DEFAULT now()
);
