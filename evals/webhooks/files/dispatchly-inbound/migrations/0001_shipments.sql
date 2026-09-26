CREATE TABLE shipments (
    id           text PRIMARY KEY,
    customer_id  text NOT NULL,
    email        text NOT NULL,
    status       text NOT NULL DEFAULT 'created',
    delivered_at timestamptz,
    created_at   timestamptz NOT NULL DEFAULT now()
);
