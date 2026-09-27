# maintdesk

Repair requests for rented flats. Tenants report a problem, the landlord
assigns a vendor (plumber, electrician), the vendor is told by SMS, and the
vendor is paid when the landlord closes the job.

Stack: Python 3.12, Postgres 16 in production (ADR-0001), plain functions
over a small repository layer; the web layer is a thin responsive site
(ADR-0002). Tests run against an in-memory store.

## Status

- Sprint 1 and sprint 2 are closed (see docs/product/sprints.md).
- Vendor payouts: the PayGate client was finished in sprint 2, so
  payouts only need wiring to the close-job flow.
- SMS goes through TextBridge (maintdesk/notify.py).

## Team

Three developers, all full time on maintdesk.

## Checks

    make check
