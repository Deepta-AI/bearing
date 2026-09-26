# subscription-renewals

Billing for the Basic and Pro plans. Data lives in SQLite through the
built-in `node:sqlite` module (schema in src/db.js); the card provider is
wrapped in src/billing.js.

Jobs (src/jobs/):

- invoice-emails.js: sends the invoice email for each new charge.
- renew-subscriptions.js: charges every subscription due for renewal.
- sweep.js: nightly housekeeping.

The app image runs cron (deploy/crontab) next to the web process, and the
deployment has 2 replicas (deploy/k8s.yaml).

No npm dependencies; Node 22.5 or later.

    make check    # node --test
