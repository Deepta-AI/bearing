# Revision protocol for design documents

Used by high-level-design, low-level-design, data-model, openapi-spec,
architecture-diagram and threat-model whenever the document they
write already exists. Iterating is running the same skill again; this file
is what makes the second run a revision and not a silent rewrite.

## When it applies

The target file exists (for example `docs/design/billing-hld.md`). A first
run writes `Version: v1` under the title and an empty `## Revision history`
section at the end. A file without a `Version:` line is v1.

## The rules

1. **Read before writing.** Read the whole current document. Its version is
   v<n>; the revision is v<n+1>. State why this revision exists in one
   sentence, naming the input that drove it: a story id, an ADR, an
   incident, a review or critic finding, a measured number, or the user's
   words.
2. **Change only what the reason touches.** Sections the reason does not
   affect are left byte for byte as they were. A revision that rewrites
   every section is a new document; say so and ask before doing it.
3. **The changes table.** Directly under the `Version:` line:

   ```
   ## Changes from v<n>
   | Section | Change | Driven by | Impact |
   | --- | --- | --- | --- |
   | 5. Data | orders gets a status_changed_at column | US-03-014 | data model v3, migration 0042 |
   ```

   One row per changed section; zero rows means nothing changed and the
   file is not written. The previous "Changes from" table moves, unedited,
   to the top of `## Revision history`, so the history reads newest first.
4. **A changed decision needs a superseding ADR, which the user decides.**
   When a revision changes a choice an ADR recorded (a store, a protocol,
   a boundary, a vendor), name the ADR it needs in the report
   (`adr "<title>"`, supersedes ADR-nnnn) and list it under the
   changes table's Impact. Write it only when the user asks for it, then
   through `adr` with status Proposed unless the user decided it in
   this conversation, naming no decider who did not decide. A revision
   never edits an accepted ADR in place, its decision or its status; the
   old ADR is marked `Superseded by` only once the new one is Accepted.
5. **Critic on the changed sections only.** When the skill offers
   `critic`, it passes the changes table and the changed sections, not
   the whole document; the three weakest claims come from what moved.
6. **Downstream.** Grep `docs/` for the file name and for the ids in the
   changed sections. Each hit is a document that may now be stale; list it
   with the skill that revises it:

   | Changed | Revise next |
   | --- | --- |
   | HLD | low-level-design per component touched, data-model, openapi-spec, threat-model |
   | LLD | the tasks in its work breakdown (start-task), test-cases |
   | Data model | db-migration, one item per changed entity (expand and contract) |
   | API spec | api-versioning for each breaking change; clients and SDKs |
   | Architecture diagram | the HLD section it contradicts, if any |
   | Threat model | vapt-report scope for the next release |

7. **Contract line.** Every skill's output contract gains:
   `Revision: v<n> -> v<n+1>, sections changed C, ADRs superseded S, downstream D`
   (or `Revision: v1 (new)` on a first run). The counts come from the
   changes table and the grep, never from memory.

## What this is not

- Not a copy per version. Git holds every version; the changes table says
  why each one exists. A skill with a shell may name the base commit
  (`git log -1 --format=%h -- <file>`); one without names v<n>.
- Not a changelog of edits to wording. Typos and phrasing are not rows.
