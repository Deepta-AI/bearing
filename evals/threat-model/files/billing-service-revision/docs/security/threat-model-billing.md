# Threat model: billing

Version: v1

## Revision history

## 1. Scope
- Scope: invoice PDF download, Razorpay webhook, customer CSV import.
- Sensitive classes: payments, PII, external input
- Serves: US-04-001, US-04-002, US-04-003

## 2. Assets
| Asset | Where | Owner |
| --- | --- | --- |
| Invoice PDFs (patient names, amounts) | invoices table | billing on-call |
| Payment state | invoices.paid_at | billing on-call |
| Customer PII (email, phone) | customers table | billing on-call |

## 3. Trust boundaries
- Internet to API over HTTPS; staff sessions by cookie.
- Razorpay to webhook over HTTPS; HMAC signature.

## 4. Threats (STRIDE)
| Id | Entry or boundary | Category | Threat | Likelihood | Impact | Mitigation | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T-01 | POST /webhooks/razorpay | Spoofing | forged payment.captured marks an invoice paid | M | H | HMAC check, internal/httpapi/webhooks.go:19 | mitigated |
| T-02 | POST /webhooks/razorpay | Tampering | replayed captured event re-applies a payment | M | M | new story: dedupe webhook events by event id | planned |
| T-03 | GET /invoices/{id}/pdf | Information disclosure | staff of tenant A read tenant B invoice by id | H | H | new story: scope invoice lookup by tenant | planned |
| T-04 | POST /imports/customers | Denial of service | unbounded CSV body exhausts memory | M | M | new story: cap import size at 5 MB | planned |
| T-05 | POST /imports/customers | Repudiation | admin import leaves no trace | M | L | US-04-007 | planned |

## 5. Residual risks
| Threat | Owner | Revisit |
| --- | --- | --- |
| T-02 | billing on-call | 2026-11-01 |
| T-03 | billing on-call | 2026-10-15 |
| T-04 | billing on-call | 2026-11-01 |
| T-05 | billing on-call | 2026-11-01 |
