CREATE TABLE clinics (
  id bigserial PRIMARY KEY,
  name text NOT NULL,
  timezone text NOT NULL DEFAULT 'Asia/Kolkata'
);

CREATE TABLE patients (
  id bigserial PRIMARY KEY,
  clinic_id bigint NOT NULL REFERENCES clinics(id),
  full_name text NOT NULL,
  phone text NOT NULL
);
