# maintdesk

Repair requests for rented flats. Tenants report a problem, the landlord
assigns a vendor (plumber, electrician), the vendor is told by SMS, and the
vendor is paid when the landlord closes the job.

Stack: Python 3.12, Postgres 16 in production (ADR-0001), plain functions
over a small repository layer; the web layer is a thin responsive site
(ADR-0002). Tests run against an in-memory store.

## Status

- Sprints 1 to 3 are closed (see docs/product/sprints.md).
- Go-live and the client acceptance window: docs/product/release-plan.md.
- Vendor payouts (ADR-0003) are not started; see the sprint 3 notes.
- SMS goes through TextBridge (maintdesk/notify.py).

## Team

Three developers, all full time on maintdesk.

## Checks

    make check
