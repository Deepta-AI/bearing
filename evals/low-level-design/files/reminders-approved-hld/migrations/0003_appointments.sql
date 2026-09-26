CREATE TABLE appointments (
  id bigserial PRIMARY KEY,
  clinic_id bigint NOT NULL REFERENCES clinics(id),
  patient_id bigint NOT NULL REFERENCES patients(id),
  starts_at timestamptz NOT NULL,
  reason text NOT NULL DEFAULT '',
  status text NOT NULL DEFAULT 'booked' -- booked | cancelled | completed
);

CREATE INDEX appointments_clinic_starts_idx ON appointments (clinic_id, starts_at);
