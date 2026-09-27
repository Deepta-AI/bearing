CREATE TABLE landlords (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL
);

CREATE TABLE vendors (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  trade TEXT NOT NULL,
  phone TEXT NOT NULL
);

CREATE TABLE repair_requests (
  id BIGSERIAL PRIMARY KEY,
  flat_id BIGINT NOT NULL,
  tenant_phone TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open',  -- open, assigned
  vendor_id BIGINT REFERENCES vendors(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
