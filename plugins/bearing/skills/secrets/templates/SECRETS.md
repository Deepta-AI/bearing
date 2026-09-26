# Secret inventory

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The inventory
     lists every secret by name, place, owner and date so each one can be
     rotated or revoked on the day it leaks; it is read by the on-call engineer
     and the security reviewer. Names only: a value never appears here, not
     even a prefix or a redacted form.
     The table: one row per secret found in the env reads, the CI file,
     compose files and infra variables marked sensitive. Type comes from
     references/rotation.md; "Where used" is a path:line; "Last rotated" is a
     date or `unknown`, never a guess. Every `unknown` and every empty owner
     is an open item in the skill's report, empty owners first.
     Example: | `STRIPE_API_KEY` | api key | `internal/billing/client.go:31` | payments team | 90 days | 2026-07-02 | yes | CI variable, masked | -->

Manager: <name and where the variables live>. Injected at: <CI variables / runtime env / mounted files>.
Scanner: gitleaks, `.gitleaks.toml`, run in pre-commit and CI. Parity: `scripts/env-parity.sh`.
Last reviewed: <YYYY-MM-DD> by <name>.

| Name | Type | Where used | Owner | Rotation period | Last rotated | Dual-read | Injected via |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `DATABASE_URL` | database credential | `<path:line>` | <team> | 90 days | unknown | yes | env |
| `<NAME>` | <api key / oauth client secret / signing key / webhook secret / tls key / ssh key> | `<path:line>` | | | | | |

Rows with `unknown` or an empty owner are open items, listed in the
skill's report until filled.

## Rotation log

<!-- What: one row per completed rotation, appended when the engineer says
     "done"; the inventory's Last rotated cell changes on the same day.
     Good: a UTC date from `date -u +%F`, the person who did it, the reason
     (scheduled, leak, person left) and whether the old value was revoked;
     a rotation whose old value is still live is two keys, not a rotation.
     Example: | 2026-09-12 | `STRIPE_API_KEY` | Priya N. | scheduled, 90 days | yes, deleted at provider 10:42Z | -->

| Date (UTC) | Name | By | Reason | Old revoked |
| --- | --- | --- | --- | --- |

## Leak records

<!-- What: one row per leak, pointing at its full record written from
     leak-record.md.
     Good: the record path exists and follows docs/security/leaks/<date>-<name>.md;
     the same secret also has a Rotation log row with reason "leak".
     Example: | 2026-08-30 | `SENDGRID_API_KEY` | `docs/security/leaks/2026-08-30-SENDGRID_API_KEY.md` | -->

| Date | Name | Record |
| --- | --- | --- |
| | | `docs/security/leaks/<date>-<name>.md` |
