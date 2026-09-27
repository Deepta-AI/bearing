# clinic-desk

Appointment booking for outpatient clinics. Each clinic is a tenant.
Front-desk staff book, reschedule and cancel appointments through the API;
the worker runs background jobs (invoice emails today) from the jobs table
in Postgres.

- `cmd/api`: HTTP API for the front desk.
- `cmd/worker`: polls the jobs table and runs due jobs.
- `internal/sms`: MSG91 client, used for OTP logins today. OTP traffic
  peaks when clinics open: about 6 requests a second from 08:45 to 09:15
  on weekdays, under 1 a second outside that window (MSG91 dashboard,
  September 2026).
- `migrations/`: SQL migrations, applied in file order.

The Postgres driver is linked in the deploy build (`-tags pgx`); `make
check` runs vet and the unit tests without a database.
