# mealbox

Account, order and support backend for the meal-kit subscription service.
Plain Python on the standard library; SQLite database (schema in
app/db.py) on a volume in production.

- app/accounts.py: sign up, log in, delete account ("Delete my account"
  in the settings page calls `delete_account`).
- app/orders.py: orders and their tax invoices.
- app/support.py: support tickets.
- app/newsletter.py: client for MailBlast, the newsletter provider
  (a processor). Contacts are pushed there by the nightly sync job.
- jobs/: scheduled jobs (deploy/cron.yaml), including the nightly
  contact sync (jobs/sync_newsletter.py).
- deploy/backup.sh: nightly database backup.

Customer-facing privacy wording lives in docs/privacy-notice.md.

    make check    # pytest
