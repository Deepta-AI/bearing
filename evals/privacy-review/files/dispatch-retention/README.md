# dispatch

Last-mile delivery backend: customers book deliveries, riders carry them,
recipients track them by phone number and confirm with an OTP.

- cmd/api: HTTP API (internal/api).
- cmd/worker: one-shot jobs, run by the Kubernetes CronJobs in
  deploy/cronjobs.yaml (`worker <job>`).
- migrations/: Postgres schema.
- Delivery proof photos and signatures (internal/proofs) go to the object storage bucket
  `dispatch-proofs`; its lifecycle rules are in deploy/storage-lifecycle.json.
- docs/privacy/retention.md is the retention schedule we give customers
  and riders (linked from the privacy notice).

The code talks to Postgres through the small `Execer` interface so the
jobs and handlers are tested without a database.

    make check    # go vet and go test
