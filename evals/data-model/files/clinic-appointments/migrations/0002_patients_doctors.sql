-- +goose Up
CREATE TABLE patients (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id   bigint NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  full_name   text NOT NULL CHECK (length(full_name) <= 200),
  phone       text NOT NULL CHECK (length(phone) <= 20),
  date_of_birth date NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_patients_tenant_id ON patients (tenant_id);

CREATE TABLE doctors (
  id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  tenant_id   bigint NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
  full_name   text NOT NULL CHECK (length(full_name) <= 200),
  active      boolean NOT NULL DEFAULT true,
  created_at  timestamptz NOT NULL DEFAULT now(),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_doctors_tenant_id ON doctors (tenant_id);

-- +goose Down
DROP TABLE doctors;
DROP TABLE patients;
