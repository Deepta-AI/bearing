# lab-intake: high-level design

Status: Approved (2025-11-20)

Partner labs send signed JSON reports to POST /webhooks/lab-report. The
service verifies the HMAC signature, parses the report, stores it in the
reports table, stamps a PDF copy with pdf-stamp, emails the clinic front
desk and acknowledges the report to the partner API.

Context diagram: docs/design/context.svg

Components: one Node.js service (3 replicas in production), Postgres 16,
an SMTP relay, the partner acknowledgement API.
