-- +goose Up
CREATE TABLE tenants (
  id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);
-- +goose Down
DROP TABLE tenants;
