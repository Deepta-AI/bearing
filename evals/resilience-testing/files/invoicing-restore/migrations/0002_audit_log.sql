CREATE TABLE audit_log (
    id          BIGSERIAL PRIMARY KEY,
    actor       TEXT NOT NULL,
    action      TEXT NOT NULL,
    at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
