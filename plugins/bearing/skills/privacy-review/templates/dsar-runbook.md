# Runbook: data subject request (access, export, delete)

- Service: <service>
- Owner (team, on-call rotation): <rotation>
- Deadline: GDPR one month; DPDP as notified in the policy
- Last verified: <YYYY-MM-DD>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The on-call
     engineer follows this runbook to answer a data subject's access, export
     or delete request. Both paths are table-driven from
     `docs/privacy/DATA_MAP.md`, so every command here covers every map row. -->

## Verify the requester

<!-- What: how to tie the request to one account before acting on it.
     Good: a delete is confirmed through the account's own login or a signed
     link to the registered email; an unverified request is never acted on.
     Example: "Requests to privacy@ from a non-registered address get the
     signed-link reply; no data is sent until the link is used." -->

1. Match the request to an account by the channel it came from.
2. For a delete, confirm through the account's own login or a signed
   link to the registered email. Never act on an unverified request.

## Export

<!-- What: the command or endpoint that returns every element for one
     subject in a machine-readable file, and how it is delivered.
     Good: the export test asserts every data map element appears and
     prints the count ("export covers 14 of 14").
     Example: "`make dsar-export SUBJECT=u_81f2` writes
     `out/dsar/u_81f2.json`; delivered via the account download page." -->

1. `<command or endpoint>` with the subject id; output `<format>`.
2. Confirm every element in `docs/privacy/DATA_MAP.md` appears
   (the export test asserts this; the count is printed).
3. Deliver over an authenticated channel; record the date.

## Delete

<!-- What: the command that removes or anonymises every element, cascades to
     processors and leaves a tombstone.
     Good: idempotent and re-runnable, logs what it did by element; covers
     events, search index, analytics exports and backups, not only the user
     row; a hashed email with a known salt is pseudonymised, not deleted.
     Example: "`make dsar-delete SUBJECT=u_81f2` prints 'deleted 12,
     anonymised 2, processors 3, tombstone written'." -->

1. `<command or endpoint>` with the subject id. Idempotent; re-run on failure.
2. The command deletes or anonymises every element by map row, calls
   each processor's deletion API (or opens the ticket listed in the
   map), and writes a tombstone (subject id hash, date, retained
   elements and their legal basis).
3. Confirm: the export for the same subject returns only the tombstone.
4. Backups: deletion is replayed on restore; note the backup retention.

## Retained under obligation

<!-- What: elements kept after a delete because a law requires it, the basis
     and the date they go.
     Good: each row names the specific obligation and an end date or rule;
     the tombstone records the same list.
     Example: | invoice billing address | tax record keeping, 8 years |
     2034-03-31 | -->

| Element | Basis | Until |
| --- | --- | --- |

## Record

<!-- What: one row per request handled, for the audit trail.
     Good: the subject is a hash, never the email or name; Completed is a
     date inside the deadline above.
     Example: | 2026-09-20 | delete | 9c1e4a... | on-call (payments) |
     2026-09-22 | -->

| Date | Type | Subject id hash | By | Completed |
| --- | --- | --- | --- | --- |

## Escalation

<!-- What: who decides when the request is ambiguous, contested, or comes
     from a third party.
     Good: a role or shared mailbox, not a person's name, and the response
     time expected from them.
     Example: "privacy@company.example, answers within 2 working days." -->

<privacy contact>, when the request is ambiguous, contested, or from a
third party.
