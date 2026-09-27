---
name: privacy-review
description: 'Reviews personal data handling: a data map with purpose, basis and retention, deletion wired to it, data subject requests, a DPIA. Use when asked about "GDPR", "DPDP", "personal data", "retention" or "delete my account".'
argument-hint: "[feature or system] [--regime gdpr|dpdp|both] [--check-only]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(mkdir -p:*), Bash(make check:*), Bash(make test:*), Bash(git diff:*), Bash(git status:*), Bash(git log:*), Bash(go test:*), Bash(go vet:*), Bash(pnpm exec vitest:*), Bash(uv run pytest:*), Bash(pytest:*), Bash(python3 -m pytest:*)
---

# privacy-review

A privacy notice is a promise; the data map is the ledger; the running
system is the only proof. This skill finds where the three disagree,
moves the system to the promise, and says plainly what it could not
prove. Most privacy bugs are not missing features: they are a job that
never runs, a sync that puts deleted people back, a cascade that
destroys a record the law says to keep, a rule on the wrong prefix.

Not this: `data-model` designs the schema and its PII column; this
skill takes that table as input. `threat-model` covers attackers;
this covers the data subject.

## Inputs

- Scope: `$1`; if absent, the whole repository. `--check-only` runs
  steps 1 to 4 and writes nothing.
- Regime: `--regime`; if absent, `both` (GDPR terms with the DPDP
  equivalents in brackets: data principal, data fiduciary). The regime
  changes the words, never the mechanisms.
- Promises, in order of authority: accepted decisions (ADRs, legal
  holds), the published notice and retention schedule, contracts with
  processors, then code comments. A comment that says "anonymised" or
  "no personal data" is a claim to test, not a fact.
- Personal data: `docs/design/data-model.md` "Retention and PII" if it
  exists; otherwise grep migrations and schema files (`*.sql`,
  `schema.prisma`, `models.py`, `ent/schema`, struct tags) for the
  identifier list in `templates/DATA_MAP.md` and its column forms
  (`dob`, `ip`, `card`). Then look outside the database: object
  storage and its lifecycle rules, log lines and their retention,
  backups, analytics tables, search indexes, caches, and every
  processor a job pushes to.
- Logging calls: grep for `log.`, `logger.`, `slog.`, `zap.`,
  `console.`, `print(`; zero hits means the logs check reports "0 log
  calls scanned" and fails.

## Scope discipline

The request sets the deliverable. "Make delete really delete" is the
delete path and what breaks it; "write down what we keep and fix the
schedule" is the map and the gaps against it. Do not add a DSAR
export, a consent system, a DPIA, admin endpoints or new purge jobs
for data the request did not raise: list them under "Not done" with
one line each. Each unrequested mechanism is code someone must review,
deploy and own, and a new deletion job is irreversible on its first run.

- Never schedule a deletion whose period is undecided. Write the job
  and its test if useful, leave it out of the scheduler, and say which
  decision it waits on. Only a period stated in an accepted document
  may run on a schedule.
- Never edit the published notice, schedule or an accepted ADR to
  match the code. Fix the code, or flag the conflict for a decision;
  a proposed wording goes in a separate draft file.
- Keep existing signatures and API contracts working (add an optional
  parameter, keep the old query string accepted) unless the change is
  the fix; say so when it is.

## Steps

1. Map. One row per personal data element: `store.table.column` (or
   bucket prefix, log field, processor), purpose, lawful basis,
   shared with, promised retention with its source (file and line, or
   "none stated"), and the mechanism that enforces it. A period nobody
   stated is written UNDEFINED, never invented. Pseudonymised is not
   anonymised: an unkeyed hash of a low-entropy identifier (a 10 digit
   phone number, an email) is reversed by hashing every candidate, so
   it stays personal data, and a key added now leaves old rows
   reversible until rewritten or purged. Print "map: N elements,
   UNDEFINED retention U". N=0 in a system with users is a wrong grep.

2. Trace every mechanism end to end. A purge function at `path:line`
   proves nothing. For each row, follow the chain and record where it
   breaks:
   - schedule entry (cron file, CronJob, timer) exists for it;
   - the argument it passes matches a name the entrypoint dispatches
     on, character for character; an unknown name must exit non-zero,
     not log and exit 0;
   - the image or build the schedule runs contains that code (a pinned
     tag older than the change runs the old binary);
   - the cutoff constant or rule equals the promise, in the same unit;
   - for object storage, the rule's prefix matches the prefix the
     writer actually uses, and versioned buckets also expire
     noncurrent versions; a rule on the wrong prefix expires nothing;
   - "they expire" is not deletion: an `expires_at` column hides a row
     and keeps it forever.
   Print "retention: N rows, enforced E, broken B, missing M".

3. Deletion paths. For a delete or erasure, walk every place the
   subject exists and every way they come back:
   - Foreign keys: list every `ON DELETE CASCADE` reachable from the
     row you would delete. If a table under a retention obligation
     (invoices, ledgers, audit records) is downstream, do not delete
     the parent: anonymise it in place, and prove the retained rows
     are unchanged (compare whole rows, not two columns).
   - Rows with no foreign key (tickets, events, logs keyed by email)
     are matched by id and by the identifiers themselves.
   - Processors: the delete calls the processor's erase API (not only
     unsubscribe) through an injected client, records failures for
     retry, and is idempotent. Then find every job that pushes to that
     processor: a sync or upsert that selects without an explicit
     "not deleted, still consented" predicate re-creates the contact
     overnight. Fix the predicate itself, and test it with a row in the
     old state (deleted flag set, consent flag still on); a test that
     only runs after your new anonymisation passes even with the bug.
   - The backlog: subjects already "deleted" by the broken path still
     have data here and at the processor. Provide an idempotent
     one-off with a dry run that prints counts, and say how to run it.
   - Backups and logs: compare their retention with the promise
     ("within 30 days including backups" against 35 days of backups is
     a broken promise); fix the number or flag it.
   - Proof: a deletion record with date, what was removed, what was
     kept and under which obligation, and no cleartext identifier.
   Database changes for one subject happen in one transaction; the
   processor call happens after commit or through a retry queue.

4. PII in logs. For every log call, check arguments against the map,
   including whole objects (`dict(user)`, `%+v` of a struct), request
   URLs with identifiers in the query string, failed-login lines, and
   error paths. Print "logs: N calls scanned, PII hits H" with
   `path:line`. Fix by logging ids or redacting; test the redaction.

5. Fix and prove. For each break found in steps 2 to 4, change the
   code toward the promise and add a test that fails on the original
   code: a registry test that every scheduled name is dispatched, a
   cutoff test at the promised boundary (one row just inside, one just
   outside), a whole-row test on retained records, the old-state sync
   test. Tests use fakes: no processor client may default to the real
   network client on a path the suite exercises, and no dependency is
   added. Run the project's check (`make check`, `go vet` and `go test`,
   or `pytest`) and print "privacy tests: N passed".

6. Rollout risks. A purge that has silently not run for months deletes
   the whole backlog on its first run; a shortened lifecycle rule
   deletes every object past the new age at once. State the expected
   size (the query that counts it), batch the delete, and say it is
   irreversible once backups age out. Name the image tag or release
   the schedule must move to, and migrations that must land first.

7. Documents. Write or update `docs/privacy/DATA_MAP.md` from
   `templates/DATA_MAP.md` (every element, with UNDEFINED where no one
   decided). `templates/dsar-runbook.md` and `templates/DPIA.md` only
   when the request is about subject requests, or the scope adds new
   processing that needs a DPIA (special categories, children, large
   scale monitoring, profiling, a new processor). Decisions you had to
   assume are written as Proposed, with no decider named.

## Output contract

```
## Privacy: <scope> (<gdpr | dpdp | both>)
Map: N elements, UNDEFINED retention U   docs/privacy/DATA_MAP.md
Promise vs system: <one line per break: promise (file:line) / reality (file:line) / fixed | flagged>
Deletion: stores covered S of S, processors erased P, re-creation paths closed R, backlog <one-off | flagged>
Logs: N calls scanned, PII hits H  <path:line ...>
Tests: N passed (check command)   each fix has a test that fails on the old code
Rollout: <first-run size, image tag, ordering>
Not run: <each real system by name: production database, bucket rules, processor account, backups>
Decisions for you: <undecided periods and conflicts, each Proposed>
Not done: <mechanisms deliberately left out of scope> | none
```

## Gotchas

- "We do not store PII" is answered by the grep, not by the team. An
  IP address or a phone number in a URL in the access log is personal
  data in both regimes.
- Soft delete (`deleted_at`) with every column intact is not deletion,
  and every query that forgets the flag resurrects the subject.
- A legal obligation to keep a record keeps that record, not the rest
  of the account; and it keeps it unchanged, so do not "anonymise" the
  billing name on a tax invoice either.
- Retention of "forever" needs a lawful basis of its own; "we might
  need it" is not one, and "anonymised" must survive a dictionary
  attack to count.
- Consent bundled into terms of service is not consent; withdrawal
  must stop the processing, including the next batch sync.
- Say "not run against" each real system by name. "Nothing deployed"
  does not tell the user that the bucket rule, the processor account
  and the backups were never touched or verified.
