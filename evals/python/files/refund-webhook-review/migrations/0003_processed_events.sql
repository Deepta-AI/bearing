-- One row per provider event we have applied. The provider delivers each
-- event at least once (docs/provider-webhooks.md); the primary key is what
-- makes a redelivery a no-op.
CREATE TABLE processed_events (
    event_id    TEXT PRIMARY KEY,
    type        TEXT NOT NULL,
    received_at TEXT NOT NULL
);
