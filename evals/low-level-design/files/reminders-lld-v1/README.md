# clinic-desk

Appointment booking for outpatient clinics. Each clinic is a tenant.
Front-desk staff book, reschedule and cancel appointments through the API;
the worker runs background jobs (invoice emails today) from the jobs table
in Postgres.

- `cmd/api`: HTTP API for the front desk.
- `cmd/worker`: polls the jobs table and runs due jobs.
- `internal/sms`: MSG91 client, used for OTP logins today.
- `migrations/`: SQL migrations, applied in file order.

The Postgres driver is linked in the deploy build (`-tags pgx`); `make
check` runs vet and the unit tests without a database.
