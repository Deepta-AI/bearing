CREATE TABLE payments (
    id          TEXT PRIMARY KEY,
    authorised  BIGINT NOT NULL,
    captured    BIGINT NOT NULL DEFAULT 0,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
