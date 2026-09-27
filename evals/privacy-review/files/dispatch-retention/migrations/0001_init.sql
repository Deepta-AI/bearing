CREATE TABLE customers (
  id          BIGSERIAL PRIMARY KEY,
  name        TEXT NOT NULL,
  phone       TEXT NOT NULL UNIQUE,
  email       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE riders (
  id              BIGSERIAL PRIMARY KEY,
  name            TEXT NOT NULL,
  phone           TEXT NOT NULL UNIQUE,
  driving_licence TEXT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE deliveries (
  id               BIGSERIAL PRIMARY KEY,
  customer_id      BIGINT NOT NULL REFERENCES customers(id),
  rider_id         BIGINT REFERENCES riders(id),
  dropoff_address  TEXT NOT NULL,
  recipient_name   TEXT NOT NULL,
  recipient_phone  TEXT NOT NULL,
  status           TEXT NOT NULL DEFAULT 'booked',
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE location_pings (
  rider_id  BIGINT NOT NULL REFERENCES riders(id),
  lat       DOUBLE PRECISION NOT NULL,
  lng       DOUBLE PRECISION NOT NULL,
  at        TIMESTAMPTZ NOT NULL
);
CREATE INDEX location_pings_at ON location_pings (at);

CREATE TABLE otp_codes (
  phone       TEXT NOT NULL,
  code        TEXT NOT NULL,
  expires_at  TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE delivery_proofs (
  delivery_id    BIGINT NOT NULL REFERENCES deliveries(id),
  photo_key      TEXT NOT NULL,
  signature_key  TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
