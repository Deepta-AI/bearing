-- +goose Up
CREATE TABLE reminders (
  id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id           bigint NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  appointment_id      bigint NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
  send_at             timestamptz NOT NULL,
  status              text NOT NULL
    CHECK (status IN ('pending', 'sent', 'delivered', 'failed')),
  attempts            smallint NOT NULL DEFAULT 0 CHECK (attempts <= 3),
  provider_message_id text NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_reminders_appointment_id ON reminders (appointment_id);
CREATE INDEX idx_reminders_pending_send_at
  ON reminders (send_at) WHERE status = 'pending';

-- +goose Down
DROP TABLE reminders;
