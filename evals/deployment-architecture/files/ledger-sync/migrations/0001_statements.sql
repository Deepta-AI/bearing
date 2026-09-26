-- +goose Up
CREATE TABLE statements (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bank_code  text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now()
);
