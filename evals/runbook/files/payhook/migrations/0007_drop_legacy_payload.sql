-- Up
ALTER TABLE events DROP COLUMN legacy_payload;

-- Down
-- Irreversible: the column and its data are gone. Re-adding an empty column
-- would not bring back the payloads that releases before 1.8.0 read.
