# ADR 0004: Product analytics through our own collector

Status: Accepted (2026-05-12)

## Context

We want product analytics for the merchant app without shipping a third
party SDK to payers' browsers, and we want the same events in the
warehouse.

## Decision

- Every event is sent to our own collector (`COLLECTOR_URL`), which writes
  to the product analytics store and the warehouse.
- The web app emits only through `src/web/analytics` and the server only
  through `src/server/analytics.js`. Nothing else talks to the collector.
- Both validate every call against one catalogue, `src/shared/events.js`,
  which mirrors docs/analytics/EVENT_SHEET.md; a test keeps them equal.
- No vendor analytics SDK is added to either side.

## Consequences

- A new event is a row in the sheet plus the same entry in the catalogue.
- The collector key is configuration (`COLLECTOR_KEY`), never in the
  repository.
