-- +goose Up
ALTER TABLE notifications ADD COLUMN attempts smallint NOT NULL DEFAULT 0;
