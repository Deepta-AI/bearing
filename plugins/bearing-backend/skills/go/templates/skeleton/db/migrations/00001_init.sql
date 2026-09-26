-- +goose Up
-- Index decision: none yet; this migration only proves the pipeline.
CREATE TABLE IF NOT EXISTS schema_probe (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    created_at timestamptz NOT NULL DEFAULT now()
);

-- +goose Down
DROP TABLE IF EXISTS schema_probe;
