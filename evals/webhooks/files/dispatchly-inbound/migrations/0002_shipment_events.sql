CREATE TABLE shipment_events (
    id          bigserial PRIMARY KEY,
    shipment_id text NOT NULL REFERENCES shipments(id),
    status      text NOT NULL,
    occurred_at timestamptz NOT NULL
);
