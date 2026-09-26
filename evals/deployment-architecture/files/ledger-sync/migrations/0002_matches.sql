-- +goose Up
CREATE TABLE matches (
  id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  statement_id bigint NOT NULL REFERENCES statements(id) ON DELETE CASCADE,
  invoice_ref  text NOT NULL,
  matched_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_matches_statement_id ON matches (statement_id);
