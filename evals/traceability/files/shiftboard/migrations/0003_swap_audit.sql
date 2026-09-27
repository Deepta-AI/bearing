CREATE TABLE swap_audit (
    id       BIGSERIAL PRIMARY KEY,
    swap_id  TEXT NOT NULL REFERENCES swaps(id),
    actor    TEXT NOT NULL,
    action   TEXT NOT NULL,
    at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
