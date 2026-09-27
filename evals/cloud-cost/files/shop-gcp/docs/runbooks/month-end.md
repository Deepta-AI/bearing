# Month-end invoicing

The VM month-end-invoicer (e2-standard-16, shop-prod, asia-south1) builds
merchant invoices. Cloud Scheduler triggers the run at 02:00 IST on the 1st
of each month; it takes 20 to 30 hours and must finish by the 3rd, when the
invoices are emailed. The rest of the month the VM runs but does nothing.

The VM has no labels; it predates the labelling policy.
