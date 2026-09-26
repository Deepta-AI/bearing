CREATE TABLE orders (
    id          text PRIMARY KEY,
    partner_id  text,
    status      text NOT NULL,
    total_minor bigint NOT NULL,
    currency    text NOT NULL,
    updated_at  timestamptz NOT NULL DEFAULT now()
);
