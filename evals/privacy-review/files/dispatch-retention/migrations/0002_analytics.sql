-- Product analytics. Phone numbers are hashed before insert
-- (internal/analytics), so this table holds no personal data.
CREATE TABLE analytics_events (
  id          BIGSERIAL PRIMARY KEY,
  phone_hash  TEXT NOT NULL,
  event       TEXT NOT NULL,
  city        TEXT,
  at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
