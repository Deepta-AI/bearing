-- +goose Up
CREATE TABLE payment_events (
    id          bigserial PRIMARY KEY,
    invoice_id  bigint REFERENCES invoices(id),
    kind        text NOT NULL,
    payload     jsonb NOT NULL,
    received_at timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE payment_events;
