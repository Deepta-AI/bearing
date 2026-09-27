# Feature flags register

Every flag in `app/flags.py` has one row. Owner is a team rotation.

## Active flags

| Flag | Default | Owner | On means | Removal task | Target date | Added |
| --- | --- | --- | --- | --- | --- | --- |
| new_pricing | off | growth-oncall | the tiered pricing page with the annual toggle replaces the legacy table | PRC-97 | 2026-11-18 | 2026-08-20 |
| bulk_invoice_download | off | billing-oncall | customers can download all invoices as one zip | BIL-40 | 2026-10-28 | 2026-07-30 |

## Removed flags

| Flag | Removed | Outcome |
| --- | --- | --- |
| dark_header | 2026-06-02 | abandoned, off branch kept |
