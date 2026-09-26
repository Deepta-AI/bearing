# partner-api: high level design

## Context

Logistics partners call the API from their own systems to read the
catalogue, place orders and pull reports. Launch is 3 November 2026.

## Components

- partner-api (this service), 3 replicas behind the ALB.
- Postgres primary for orders; a read replica for reports.
- Redis (ElastiCache) for the catalogue cache (ADR 0004).

## Scaling and limits

- Partners at launch: 35, each with one API key. 3 of them are on the
  Gold tier.
- Contracted rate: 600 requests per minute per partner key, with short
  bursts of up to 50 requests allowed. Gold partners: 1,500 per minute.
- POST /v1/reports/export runs a 2 to 8 s query on the read replica,
  which can serve 20 concurrent report queries before other reports
  slow down. The contract allows 5 exports per minute per partner.
- Expected total peak at launch: about 180 requests per second across
  all partners.
