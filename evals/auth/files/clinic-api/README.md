# clinic-api

Appointments API for a group of outpatient clinics. Each clinic is a
tenant; staff belong to exactly one clinic and have one role: admin,
doctor or receptionist. The web front end logs in with POST /login and
then sends the `sid` cookie on every request.

Storage is in memory for now (seeded in internal/store/seed.go); the
Postgres port is a later story.

    make check    # go vet and go test
    go run ./cmd/api
