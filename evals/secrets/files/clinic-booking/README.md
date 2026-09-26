# clinic-booking

Appointment booking for the clinic network: patients book online, clinics get
an email per booking, patients get an SMS reminder, and the nightly worker
writes the day's report to object storage with a signed download link.

## Run

    make check        # compile and unit tests
    docker compose up # local Postgres on :5432

Copy `.env.example` to `.env` for local runs. Production values are kept in
Vault under `secret/clinic-booking/` and reach the pods through the
`clinic-booking-secrets` Kubernetes secret (see `deploy/k8s.yaml`).

Secret owners and rotation are tracked in `docs/ops/secrets.md`.
