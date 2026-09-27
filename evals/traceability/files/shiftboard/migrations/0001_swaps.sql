CREATE TABLE swaps (
    id           TEXT PRIMARY KEY,
    requester_id TEXT NOT NULL,
    shift_id     TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'pending',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
