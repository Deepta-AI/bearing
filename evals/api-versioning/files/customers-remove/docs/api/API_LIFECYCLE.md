# API lifecycle

Strategy: URL versioning `/vN/`. Spec: `api/openapi.yaml`.
Last reviewed: 2026-08-18.

## Policy

- Deprecation notice period: 90 days minimum.
- Deprecated operations send `Deprecation`, `Sunset` and a `Link` to
  the successor on every response.
- Removal gate: no requests to the operation in the gateway access logs
  for 30 days, Sunset in the past, every consumer notified.

## Consumer inventory

| Consumer (system) | Identified in logs by | Operations used | Contact |
| --- | --- | --- | --- |
| Shop iOS app | key `shopapp-ios` | `GET /v2/customers/{id}/addresses` | #mobile-team |
| Shop Android app | key `shopapp-android` | `GET /v2/customers/{id}/addresses` | #mobile-team |
| Acme warehouse | key `acme-wms` | `GET /v2/customers/{id}/addresses` (moved from v1 on 2026-08-12) | integrations@acme-wms.example.in |

## Deprecated operations

| Operation | Deprecated on | Sunset | Successor | Notice | Consumers notified | Status |
| --- | --- | --- | --- | --- | --- | --- |
| `GET /v1/customers/{id}/addresses` | 2026-05-17 | 2026-08-15 | `GET /v2/customers/{id}/addresses` | `docs/api/deprecations/get-v1-customers-addresses.md` | 3 of 3 | deprecated |

## Removed operations

| Operation | Removed on | Gate evidence (window, requests, total) | Commit |
| --- | --- | --- | --- |
