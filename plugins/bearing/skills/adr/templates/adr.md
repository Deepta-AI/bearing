# ADR-0000: Title in the imperative (Use X for Y)

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. An ADR records
     one decision a future reader will ask "why" about; under 120 lines.
     Area is the tech-decision catalogue key where one fits (database,
     messaging, compute, auth, api style...), else a short noun.
     Reversibility is cheap, awkward or irreversible, then what reversing
     would cost: the most useful fact about a decision and the least often
     written down. -->

- Status: Proposed | Accepted | Superseded by ADR-nnnn
- Date: YYYY-MM-DD
- Task: TASK-ID
- Deciders: names or roles
- Area: catalogue key
- Reversibility: cheap | awkward | irreversible: what reversing costs

## Context

<!-- What: the situation that forces a decision now: the facts, constraints
     and numbers, and nothing about the options yet.
     Good: every claim is checkable (a file, a metric, a date, a quote from
     the request marked "from the request"); the reader sees why doing
     nothing is not an option; when nothing here is unusual, it says so and
     the catalogue default applies.
     Example: "Sessions live in Redis (internal/session/store.go, 12 hour TTL);
     Redis serves nothing else and costs a managed instance per environment." -->

## What else was considered

<!-- What: a table Option | Why not | Would suit, the chosen option first
     marked "(chosen)" with what it costs in Why not, then at least one real
     alternative; "keep what we have" counts when it was weighed.
     Good: each Why not names cost and risk in the same terms so they
     compare; Would suit names the fact that would make the rejected option
     right (a volume, a team shape, a requirement), which is the revisit
     trigger for someone six months on. If only one option was ever on the
     table, write "No alternative was considered" as the second row.
     Example: "| Signed cookies | no way to revoke a session before it
     expires, which the security review requires | sessions that never need
     revoking, such as a read-only public catalogue |" -->

| Option | Why not | Would suit |
| --- | --- | --- |

## Decision

<!-- What: one sentence starting "We will", then the reasons that decided
     it, most important first.
     Good: the reasons refer back to the context and the options; a reader
     could disagree with the weighting but not misread it.
     Example: "We will store sessions in a Postgres table with expires_at,
     purged hourly by the existing jobs worker, because..." -->

## Consequences

<!-- What: what changes because of this decision.
     Good: includes what becomes harder and what we accept about it, and the
     concrete trigger that should make someone revisit it (a number, an
     event, a date), not "if things change".
     Example: "Revisit if session reads pass 2,000 per second at peak or the
     purge job takes longer than 5 minutes." -->

## Commits us to

<!-- What: every named product, service or library this decision commits
     the team to, comma separated, exactly as named, including the ones
     inside the standard stack.
     Good: versions where they matter; a technology that is not a tech-decision
     catalogue default is marked "(outside the standard stack)" so the HLD
     lists it for Architect or Engineering Manager sign-off.
     Example: "PostgreSQL 16, pgx v5, goose, Caddy (outside the standard
     stack)" -->
