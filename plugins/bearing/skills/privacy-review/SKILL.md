---
name: privacy-review
description: 'Reviews personal data handling: a data map with purpose, basis and retention, deletion wired to it, data subject requests, a DPIA. Use when asked about "GDPR", "DPDP", "personal data", "retention" or "delete my account".'
argument-hint: "[feature or system] [--regime gdpr|dpdp|both] [--check-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(make check:*), Bash(make test:*), Bash(git diff:*), Bash(git status:*), Bash(go test:*), Bash(pnpm exec vitest:*), Bash(uv run pytest:*)
---

# privacy-review

A privacy policy is a promise; the data map is the ledger; the delete
path is the proof. This skill writes the ledger from the schema, wires
retention and deletion to every row of it, and checks the logs for what
the ledger says should not be there.

Not this: `data-model` designs the schema and its PII column; this
skill takes that table as input. `threat-model` covers attackers;
this covers the data subject.

## Inputs

- Scope: `$1`; if absent, the whole repository. `--check-only` runs
  steps 1, 5 and 6 and writes nothing.
- Regime: `--regime`; if absent, `both` (GDPR terms with the DPDP
  equivalents in brackets: data principal, data fiduciary, consent
  manager). The regime never changes the mechanisms, only the words.
- PII table: `docs/design/data-model.md` section "Retention and PII";
  if absent, grep migrations and schema files (`*.sql`, `schema.prisma`,
  `models.py`, `ent/schema`, `*.go` struct tags) for column names in
  `templates/DATA_MAP.md`'s identifier list (the one list; each entry
  also matched by its common column forms, such as `dob` for date of
  birth, `ip` for ip address, `card` for payment card) and say "data map:
  from schema grep, review the kinds".
- Logging calls: grep for `log.`, `logger.`, `slog.`, `zap.`,
  `console.`, `print(`; zero hits: the logs check reports "0 log calls
  scanned" and fails.
- Consent: an existing `consents` or `preferences` table; if absent,
  designed in step 4.
- Templates: `templates/DATA_MAP.md` to `docs/privacy/DATA_MAP.md`,
  `templates/DPIA.md` to `docs/privacy/DPIA-<kebab>.md`,
  `templates/dsar-runbook.md` to `docs/runbooks/dsar.md`.

## Steps

1. Data map: one row per personal data element: kind, store and
   column (`store.table.column`), purpose, lawful basis (consent,
   contract, legal obligation, legitimate interest; DPDP: consent or
   legitimate use), collected from, shared with (processors, third
   parties), retention window, deletion mechanism, owner. Print "data
   map: N elements, UNDEFINED retention U, UNDEFINED mechanism M". N=0:
   stop with "0 personal data elements found in <scope>"; a system
   with users and zero elements is a wrong grep, not a clean bill.
2. Retention wired: for every row with a window, a mechanism exists in
   code (a scheduled job, a TTL index, a partition drop, an
   anonymising update) and is named as `path:line`; missing ones are
   written as jobs (`background-jobs` shape: period-keyed, idempotent, counted)
   and listed. Print "retention: N rows, mechanisms present P, added A".
3. DSAR paths: an export that returns every element for one subject in
   a machine-readable file, and a delete that removes or anonymises
   every element, cascades to processors (a list of API calls or
   tickets), and leaves a tombstone (subject id hash, date, what was
   kept under legal obligation and why). Both are table-driven from the
   data map, so a new row without a handler fails a test. Print "DSAR:
   export covers N of N, delete covers N of N".
4. Consent and preferences: a `consents(subject_id, purpose, granted,
   version, at, source)` table, append-only; every purpose with lawful
   basis "consent" in the map has a purpose key; reads check the latest
   row; withdrawal is a new row and stops the purpose's processing.
5. PII in logs: for every log call, check the arguments against the
   map's identifiers and the struct or model types that carry them
   (logging a whole `user` object counts). Print "logs: N calls
   scanned, PII hits H" with `path:line` for each hit. Fix by logging
   ids and redacting fields; a hit in an error path is still a hit.
6. DPIA from `templates/DPIA.md` when the scope processes special
   categories, children's data, large-scale monitoring, profiling, or
   a new processor; otherwise a one-line "DPIA not required because
   ..." in DATA_MAP.md. Tests: export and delete against a seeded
   subject (every element present, then absent), retention job removes
   a row past its window and keeps one inside it, consent withdrawal
   stops the purpose. Run; print "privacy tests: N passed".
7. Write the docs and print the contract.

## Output contract

```
## Privacy: <scope> (<gdpr | dpdp | both>)
Data map: N elements (from <data-model | schema grep>), UNDEFINED retention U, mechanism M
Retention: N rows, mechanisms present P, added A  <path:line ...>
DSAR: export N of N, delete N of N, processors cascaded C; runbook docs/runbooks/dsar.md
Consent: purposes K, table <name> (<present | added>)
Logs: N calls scanned, PII hits H  <path:line ...>
DPIA: docs/privacy/DPIA-<kebab>.md | not required: <reason>
Tests: N passed   Docs: docs/privacy/DATA_MAP.md
Not done: <list> | none
```

## Gotchas

- "We do not store PII" is answered by the grep, not by the team. An
  IP address in a request log is personal data in both regimes.
- Deleting the user row and leaving the events table, the backups, the
  search index and the analytics export is not deletion. The map's
  "shared with" column is the cascade list.
- Anonymised means no one can re-identify, including with the other
  columns; a hashed email with a known salt is pseudonymised and stays
  in the map.
- Retention of "forever" needs a lawful basis of its own; "we might
  need it" is not one.
- Consent bundled into terms of service is not consent. One purpose,
  one row, withdrawable as easily as given.
- Backups are in scope: the map says how long a deleted subject stays
  restorable and that a restore replays deletions.
- A DSAR delete that fails halfway leaves a subject half-present; make
  it idempotent and re-runnable, and log what it did by element.
