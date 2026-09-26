# Architecture decisions: <project>

<!-- Template guidance: written to docs/architecture/decisions.md. It is the
     index of every ADR (one row each; the ADR file holds the reasoning) and
     the register of conflicts that were settled: two parts of the design
     disagreeing, or the design disagreeing with an agreed acceptance
     criterion. high-level-design writes it when it reconciles the ADRs against the
     stories and the data model; adr adds or updates a row whenever it
     writes or supersedes an ADR. tech-decision's docs/decisions.md is the log
     of technology keys; this file is per ADR. Delete each comment when you
     fill its section. -->

One row per decision, and every contradiction settled once so it is not
settled again, differently, in each file that runs into it.

## Decisions

<!-- What: one row per ADR file in the ADR directory, as Id | Title | Area |
     Status | Reversibility.
     Good: Area is a tech-decision catalogue key where one fits; Status is
     Proposed, Accepted, Superseded by ADR-nnnn, Deprecated or Rejected;
     Reversibility starts cheap, awkward or irreversible and says what
     reversing would cost; no ADR file is missing a row.
     Example: "| ADR-0004 | Use Postgres for orders | database | Accepted |
     irreversible: every table and query would move |" -->

| Id | Title | Area | Status | Reversibility |
| --- | --- | --- | --- | --- |

## Conflicts that were settled

<!-- What: one "### <the question, in one sentence>" per contradiction found
     between ADRs, stories (acceptance criteria) and the data model, each
     with "**Between:**" (story ids, data model tables, ADR ids),
     "**Decision.**", "**Why.**", "**Settled by:**" and "**What now has to
     change to match:**" with one bullet per artifact to amend. When the
     reconciliation found nothing, one line "None found: <what was
     compared>".
     Good: the decision is specific enough to build from, never "both are
     valid"; Settled by names the person or role who decided, "Proposed"
     when autopilot decided it, or "open" while nobody has (an open
     conflict blocks an Approved HLD); a signed-off story wins unless
     following it breaks the architecture, and then the criterion Product
     must amend is named.
     Example: "### Whether attachments go through the API or straight to
     object storage / Between: US-02-004, attachments, ADR-0006 / Decision.
     Multipart through the API, which sniffs the content type. / Why. The
     table stores a sniffed type at write time. / Settled by: Architect /
     What now has to change to match: - ADR-0006 consequences: drop signed
     PUT uploads" -->
