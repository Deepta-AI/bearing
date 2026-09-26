# Data map

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The data map is
     the ledger of every personal data element: engineers wire retention and
     deletion to it, the DSAR export and delete are driven from it, and the
     privacy contact reviews it. Keep the identifier list below; privacy-review
     greps the schema for it when there is no data model. -->

Regime: <GDPR / DPDP / both>. Controller (data fiduciary): <organisation>. Privacy contact: <role or address>.
Source: <docs/design/data-model.md PII table / schema grep on YYYY-MM-DD>. Last reviewed: <YYYY-MM-DD> by <name>.

Identifiers this map looks for: email, phone, name, address, date of
birth, ip address, device id, national id, tax id, pan, aadhaar, passport, payment
card, location, photo, biometric, health, employment, financial.

## Elements

<!-- What: one row per personal data element: kind, `store.table.column`,
     purpose, lawful basis, where it came from, who it is shared with,
     retention window, deletion mechanism and owner.
     Good: basis is one of consent, contract, legal obligation, legitimate
     interest (DPDP: consent or legitimate use); the mechanism is a `path:line`
     (job, TTL index, partition drop, anonymising update); IP addresses in
     logs and hashed emails are rows too. `UNDEFINED` in Retention or Deletion
     is an open item and appears in the skill's report until filled. Zero rows
     in a system with users is a wrong grep, not a clean bill.
     Example: the two rows below; replace them with the real elements. -->

| # | Kind | Store.table.column | Purpose | Lawful basis | Collected from | Shared with | Retention | Deletion mechanism (`path:line`) | Owner |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | email | `postgres.users.email` | account login and notices | contract | the subject | email provider (processor) | account life + 30 days | `internal/jobs/purge_users.go:41` | <team> |
| 2 | ip address | `logs.http.client_ip` | abuse prevention | legitimate interest | request | none | 14 days | log retention policy | <team> |

## Processors and third parties

<!-- What: every processor or third party named in the Elements "Shared
     with" column: what they receive, why, the contract, and how to delete
     a subject's data there.
     Good: this table is the DSAR delete's cascade list, so each row has a
     deletion API call or a named ticket route; "email them" is not one.
     Example: | Postmark | 1 (email) | transactional email | DPA signed
     2026-03-02 | `DELETE /suppressions` plus support ticket for logs | -->

| Name | Elements | Purpose | Contract / DPA | Deletion API or contact |
| --- | --- | --- | --- | --- |

## Consent purposes

<!-- What: one row per purpose whose lawful basis in the map is consent: its
     purpose key in the consents table, the elements it covers, where the
     question is asked and what withdrawal stops.
     Good: one purpose per row, never bundled into terms of service;
     withdrawal is a new consents row and names the processing it halts.
     Example: | marketing_email | 1 (email) | signup form, settings page |
     newsletter sends stop at the next batch; address kept for login | -->

| Purpose key | Elements | Where asked | Withdrawal effect |
| --- | --- | --- | --- |

## Backups

<!-- What: how long backups are kept, so how long a deleted subject stays
     restorable, and that a restore replays the deletion log.
     Good: the number of days comes from the backup configuration or
     deployment.md, not memory; name where the deletion log lives.
     Example: "Retention of backups: 35 days (RDS automated snapshots). A
     restore replays `privacy_deletions` before the service takes traffic." -->

Retention of backups: <days>. A deleted subject is restorable for at
most that long; a restore replays the deletion log.

## DPIA

<!-- What: the path to the DPIA, or one line saying why none is required.
     Good: a DPIA is required for special categories, children's data,
     large-scale monitoring, profiling or a new processor; "not required"
     names which of those is absent.
     Example: "not required because the scope adds no special category,
     children's data, monitoring, profiling or new processor." -->

<`docs/privacy/DPIA-<kebab>.md` | not required because <reason>>
