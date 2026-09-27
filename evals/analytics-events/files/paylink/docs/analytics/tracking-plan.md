# Tracking plan

## Identity

- Merchants: anonymous id from the web module until login; on login the
  server calls `identify(user_id)` and the web module sets `tenant_id` to
  the merchant account id. `logout` resets both.
- Payers are not users. They are never identified and never aliased.

## Consent

- The web module drops every call until `setConsent(true)`; nothing is
  queued. Merchants answer the consent banner in the app shell.
- Server-side events about payers carry no payer identifiers (no email,
  no name, no IP address, no free text the payer typed). They are keyed by
  `invoice_id` and the merchant's `tenant_id`.

## Standard properties (stamped by the modules, never passed per call)

| Property | Source |
| --- | --- |
| `app_version` | build |
| `platform` | `web` or `server` |
| `tenant_id` | merchant account id |
| `page_path` | web only: `location.pathname` |
| `request_id` | server only |

## Destinations

Collector, which fans out to product analytics and the warehouse.
