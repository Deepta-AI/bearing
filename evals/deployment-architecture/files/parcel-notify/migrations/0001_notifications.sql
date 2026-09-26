-- +goose Up
CREATE TABLE notifications (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  parcel_ref  text NOT NULL,
  channel     text NOT NULL CHECK (channel IN ('whatsapp', 'email')),
  status      text NOT NULL DEFAULT 'queued',
  created_at  timestamptz NOT NULL DEFAULT now()
);
