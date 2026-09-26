# Handover pack: <client>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The pack is
     what the client's next team works from when nobody from the engagement
     is on the call. Facts come from the repository and its documents only,
     never from querying production; a fact not found is "unconfirmed:" with
     what to ask and whom, never an invented host, URL or account. Saved as
     docs/handover/HANDOVER.md. -->

Delivered by: the entity named in `.bearing/company.json` | another entity
Prepared: <date>   Version handed over: <tag or commit>   Prepared from: <repository>

Every section names its source (a file or a command) or is marked
`unconfirmed:` with who can confirm it.

## 1. System overview

<!-- What: what the system does and for whom in five lines, then the
     components and their responsibilities, then the diagrams by path.
     Good: taken from the HLD and README; diagrams referenced by their path
     in docs/design/, never redrawn; no claim the sources do not make.
     Example: "Clinic lab-report intake: parses emailed reports and files
     them against the patient record. Diagrams: docs/design/context.svg" -->

Source: <docs/design/HLD.md, README.md>

## 2. Environments and URLs

<!-- What: one row per environment with its purpose, URL and owner.
     Good: every URL is found in a named repository file (CI variables,
     deploy/, terraform/); one that is not reads "unconfirmed: ask <whom>".
     Example: "| staging | client UAT | https://staging.labintake.example.in
     (deploy/staging/values.yaml) | client IT, R. Menon | resets nightly |" -->

Source: <files>

| Environment | Purpose | URL | Owner | Notes |
| --- | --- | --- | --- | --- |
| dev / staging / production | | <url or unconfirmed:> | | |

## 3. Access inventory

<!-- What: one row per account, service user, key or role, with its purpose
     and where the credential lives.
     Good: a secret manager path, vault path or CI variable name, never a
     value, not even a local development one; a value found in the repository
     becomes a known issue in section 8. Scan the draft for AKIA, -----BEGIN,
     token=, password=, secret= and 32 or more hex characters before writing.
     Example: "| orders-db-app | Postgres prod | app read/write | AWS Secrets
     Manager prod/orders/db | platform team |" -->

Source: <.env.example, CI variables, terraform>. Values never appear here.

| Account or role | System | Purpose | Credential lives in | Holder |
| --- | --- | --- | --- | --- |
| | | | <secret manager path, vault, CI variable name> | |

## 4. Repositories and branches

<!-- What: one row per repository with its remote, branches and latest tag.
     Good: read from .git/config (remotes), .git/HEAD (branch) and
     .git/packed-refs or .git/refs/tags/ (tags); the last tag is the
     delivered version; a fact that needs a command is "unconfirmed:" with
     the command.
     Example: "| lab-intake | git@gitlab.example.in:clinic/lab-intake.git |
     main | release/1.4 | v1.4.2 |" -->

Source: git remote -v, git branch -r, git tag

| Repository | Remote | Default branch | Release branch | Latest tag |
| --- | --- | --- | --- | --- |

## 5. Build and deploy procedure

<!-- What: the numbered steps from a clean checkout to a deployed version,
     then how to roll back.
     Good: each step is an exact command taken from a Makefile recipe or a
     CI job read in the file (an included file is read too); a target
     defined only in a missing file is "unconfirmed:"; rollback names the
     mechanism and the command.
     Example: "1. make build VERSION=v1.4.2 (Makefile:22, builds and pushes
     the image)" -->

Source: <Makefile, .gitlab-ci.yml, deploy/>

1. <step with the exact command>
2.

Rollback: <mechanism and command, or unconfirmed:>

## 6. Runbooks index

<!-- What: one row per alert with its runbook and when it was last verified.
     Good: a runbook whose "Last verified" is over ninety days old or reads
     "not run" is listed as stale, never hidden.
     Example: "| ReadinessFailing | docs/runbooks/ReadinessFailing.md |
     2026-08-12 | current |" -->

Source: docs/runbooks/

| Alert | Runbook | Last verified | Status |
| --- | --- | --- | --- |
| | docs/runbooks/<file> | <date> | current / stale |

## 7. Monitoring and alerting

<!-- What: every alert rule and dashboard, where it lives, what fires it
     and who it notifies.
     Good: read from monitoring rules and alert YAML with the file path;
     the threshold is the rule's own expression and duration, not a summary.
     Example: "| HealthFlapping | monitoring/alerts/orders-health.yaml |
     changes(probe_success[15m]) > 3 | #orders-oncall |" -->

Source: <monitoring rules, dashboards>

| Alert or dashboard | Where | Threshold | Notifies |
| --- | --- | --- | --- |

## 8. Known issues and technical debt

<!-- What: traceability gaps, TODO, FIXME and HACK counts by directory, open
     postmortem actions and "Noticed" items from the docs.
     Good: every item has its ticket key; an unticketed one gets HO-nn and
     the flag unticketed:; missing design, ADR or runbook docs are an item
     naming the skill that produces them.
     Example: "| HO-03 unticketed: | 14 TODO markers | internal/parser/ |
     medium | ticket and schedule before v1.5 |" -->

Source: docs/traceability.md, grep TODO/FIXME/HACK, docs/postmortems/

| Id | Description | Where | Severity | Action |
| --- | --- | --- | --- | --- |
| <PREFIX>-<n> or HO-nn (unticketed:) | | | | |

## 9. Support and escalation

<!-- What: who the client contacts at each level, how, when and how fast.
     Good: from SECURITY.md, CODEOWNERS or the contract, with the file named;
     anything not written down is "unconfirmed:" naming who can confirm it.
     Example: "| L2 | delivery support desk | support@example.in | Mon to Fri
     09:00 to 18:00 IST | 4 business hours (contract, schedule B) |" -->

Source: <SECURITY.md, CODEOWNERS, contract, or unconfirmed:>

| Level | Who | How | Hours | Response target |
| --- | --- | --- | --- | --- |

## 10. Licence and third-party inventory

<!-- What: each dependency with its version, licence, purpose and group.
     Good: licence read from the manifest or lock file where a licence field
     exists, otherwise "unconfirmed:"; grouped as runtime, build or
     infrastructure; the counts match the contract line.
     Example: "| github.com/jackc/pgx/v5 | 5.6.0 | MIT | Postgres driver |
     runtime |" -->

Source: <manifests and lock files>

| Component | Version | Licence | Used for | Group |
| --- | --- | --- | --- | --- |
| | | <licence or unconfirmed:> | | runtime / build / infrastructure |

## 11. Open items at handover

<!-- What: what is still outstanding on the day of handover and who closes it.
     Good: each item has an owner, named on the delivering or the client
     side, and a due date; "someone" or "later" is not an entry.
     Example: "| 1 | Confirm the production URL (section 2) | client IT,
     R. Menon | 2026-10-05 |" -->

| # | Item | Owner | Due |
| --- | --- | --- | --- |

## 12. Sign-off

<!-- What: the acceptance page: entity, client, delivered version, date and
     blank signature lines.
     Good: always the last section; the version is the last tag or commit
     from section 4; the signature cells stay blank for real signatures.
     Example: "Version accepted: v1.4.2   Date: 2026-10-01" -->

Delivering entity: the entity named in `.bearing/company.json` | another entity
Client: <client>
Version accepted: <tag or commit>   Date: <date>

| Role | Name | Signature | Date |
| --- | --- | --- | --- |
| For the delivering entity | | | |
| For the client | | | |
