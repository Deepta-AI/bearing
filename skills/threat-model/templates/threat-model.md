# Threat model: <feature or system>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. A threat model
     lists what an attacker wants, where they can get in and what stops them,
     before the code is written; vapt-report and /security-review read it to
     check the mitigations exist. Anything not read from a file is marked
     "assumption:". Never write real secrets, tokens or PII samples. -->

- Task: TASK-ID
- Serves: US-nn-nnn, REQ-nnn, ADR-nnnn
- HLD: docs/design/<title>-hld.md; diagram: docs/architecture/<scope>-c4.md
- Sensitive classes: auth | payments | PII | external input | none
- Author, date, status (Draft | Reviewed | Approved | FAILED: <reason>)

## 1. Assets

<!-- What: what an attacker wants in this scope (credentials, PII, money,
     availability, audit integrity), where each lives and who owns it.
     Good: the location is a store, cookie or file you can point at; the
     owner is a rotation or role, never a person's name; one row per asset,
     not "user data".
     Example: "invoice PDFs | s3 bucket billing-invoices | billing on-call |
     customer names, addresses and amounts owed" -->

| Asset | Where it lives | Owner | Why an attacker wants it |
| --- | --- | --- | --- |
| session tokens | redis, cookie | platform rotation | account takeover |

## 2. Trust boundaries

<!-- What: each edge that crosses a boundary: internet to ingress, service
     to store, service to external, user role to admin role; its protocol
     and the auth on it.
     Good: the Source column is a file:line (compose, k8s, env host, C4
     diagram); a boundary taken from the HLD or guessed says "assumption:"
     so the count of assumed boundaries is honest.
     Example: "B3 | api | stripe | HTTPS | secret key from vault |
     deploy/api/env.yaml:18" -->

| # | From | To | Protocol | Auth on the edge | Source |
| --- | --- | --- | --- | --- | --- |
| B1 | internet | ingress | HTTPS | none until API | k8s/ingress.yaml:12 |
| B2 | api | postgres | TLS, SQL | role per service | assumption: |

## 3. Entry points

<!-- What: every route, consumer, cron job, upload, callback and admin
     screen in scope, its auth requirement and the boundary it crosses.
     Good: taken from api/openapi.yaml or grepped from the code, not
     remembered; webhooks, imported CSVs and third-party callbacks count as
     external input, not only the public API.
     Example: "E3 | POST /api/v1/imports (CSV upload) | upload | bearer,
     admin role | B1" -->

| # | Entry point | Kind | Auth required | Boundary |
| --- | --- | --- | --- | --- |
| E1 | POST /api/v1/invoices | route | bearer, tenant scoped | B1 |
| E2 | payment webhook | callback | HMAC signature | B1 |

## 4. Threats (STRIDE)

<!-- What: for each entry point and boundary, the six STRIDE categories;
     one row per threat with id T-nn, likelihood and impact (L, M, H), a
     mitigation and a status (mitigated, planned, unmitigated).
     Good: the mitigation is an existing file:line, a backlog story id
     US-nn-nnn or "new story: <title>"; "handled by the framework" and a
     bare "rate limiting" fail the gate. Authorisation is per record, not
     per role. Ids never change once written; a revision marks a row
     "retired in v2: <reason>" instead of deleting it.
     Example: see T-01 to T-03 below; replace them with this scope's rows. -->

| Id | Entry or boundary | Category | Threat | Likelihood | Impact | Mitigation | Status |
| --- | --- | --- | --- | --- | --- | --- | --- |
| T-01 | E2 | Spoofing | forged webhook posts a paid status | M | H | verify HMAC, internal/webhooks/verify.go:40 | mitigated |
| T-02 | E1 | Elevation | caller reads another tenant's invoice by id | M | H | new story: per-record tenant check on invoice reads | planned |
| T-03 | E1 | Repudiation | considered, none: audit log covers writes (US-05-002) | | | | |

Categories: Spoofing, Tampering, Repudiation, Information disclosure,
Denial of service, Elevation of privilege. Each entry point and boundary
has a row per category, or "considered, none" with the reason.

## 5. Residual risks

<!-- What: every planned or unmitigated threat from section 4, whether the
     risk is accepted or planned, who owns it and when it is looked at
     again.
     Good: the owner is a rotation or role, not a person's name; the revisit
     is a date, not "later"; the count here equals planned plus unmitigated.
     Example: "T-07 | accepted: CSV import has no virus scan, admin-only
     upload | security champion rotation | 2026-12-01" -->

| Threat | Risk accepted or planned | Owner (role) | Revisit |
| --- | --- | --- | --- |
| T-02 | planned in US-nn-nnn | backend lead rotation | <date> |

## 6. New stories needed

<!-- What: one line per "new story:" mitigation in section 4, with the
     threat it closes and a one-line acceptance.
     Good: the title matches the mitigation cell so the backlog story can
     be traced back to its threat; the acceptance is testable.
     Example: "Per-record tenant check on invoice reads (mitigates T-02),
     acceptance: tenant A gets 404 for tenant B's invoice id." -->

- <title> (mitigates T-nn), acceptance: <one line>

## 7. Counts

<!-- What: the counts from the sections above and the gate result.
     Good: the threat counts and the gate come from the threats_check.py
     output, never counted by hand; a sensitive scope with zero threats
     reads FAILED, not passed.
     Example: "Assets 4, boundaries 3, entry points 6, threats 11
     (mitigated 7, planned 3, unmitigated 1). Gate: passed." -->

Assets N, boundaries N, entry points N, threats N (mitigated N, planned
N, unmitigated N). Gate: passed | FAILED.
