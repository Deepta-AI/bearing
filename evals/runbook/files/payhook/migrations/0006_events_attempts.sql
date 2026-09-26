-- Up
ALTER TABLE events ADD COLUMN attempts INTEGER NOT NULL DEFAULT 0;
ALTER TABLE events ADD COLUMN last_error TEXT;

-- Down
ALTER TABLE events DROP COLUMN last_error;
ALTER TABLE events DROP COLUMN attempts;
