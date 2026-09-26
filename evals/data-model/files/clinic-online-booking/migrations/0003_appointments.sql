-- +goose Up
CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE TABLE appointments (
  id               bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id        bigint NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  doctor_id        bigint NOT NULL REFERENCES doctors(id) ON DELETE RESTRICT,
  patient_id       bigint NOT NULL REFERENCES patients(id) ON DELETE RESTRICT,
  starts_at        timestamptz NOT NULL,
  ends_at          timestamptz NOT NULL,
  status           text NOT NULL
    CONSTRAINT appointments_status_check
    CHECK (status IN ('booked', 'cancelled', 'completed', 'no_show')),
  reason_for_visit text NULL CHECK (length(reason_for_visit) <= 500),
  cancel_reason    text NULL CHECK (length(cancel_reason) <= 500),
  fee_minor        bigint NOT NULL CHECK (fee_minor >= 0),
  currency         char(3) NOT NULL DEFAULT 'INR',
  created_at       timestamptz NOT NULL DEFAULT now(),
  updated_at       timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT appointments_ends_after_starts CHECK (ends_at > starts_at),
  CONSTRAINT appointments_no_overlap EXCLUDE USING gist (
    doctor_id WITH =, tstzrange(starts_at, ends_at) WITH &&
  ) WHERE (status <> 'cancelled')
);
CREATE INDEX idx_appointments_tenant_doctor_starts
  ON appointments (tenant_id, doctor_id, starts_at);
CREATE INDEX idx_appointments_tenant_patient_starts
  ON appointments (tenant_id, patient_id, starts_at DESC);

-- +goose Down
DROP TABLE appointments;
