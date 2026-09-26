-- +goose Up
CREATE TABLE tenants (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name        text NOT NULL CHECK (length(name) <= 200),
  timezone    text NOT NULL DEFAULT 'Asia/Kolkata',
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE tenants;
