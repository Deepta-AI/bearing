---
name: tech-decision
description: 'Chooses between technology options: lays out options, recommends with reasons, lets the user decide, records each choice as an ADR. Use when asked "Kafka or RabbitMQ", "which cloud" or "what stack should we use".'
argument-hint: "[decision keys, e.g. cloud compute messaging] or a question in plain words"
allowed-tools: Read, Write, Grep, Glob, Skill, Bash(ls:*), Bash(git log:*)
---

# tech-decision

Ask, recommend, let the user decide, record. Never pick silently, never
refuse to recommend, never stop at the user's first word without showing
the better option when there is one.

Not this: `adr` records a decision already made; this skill is how
the decision gets made, and it records through `adr`'s template.

## Inputs

- Decision keys: looks in `$ARGUMENTS`, the calling skill's list, or the
  technologies the request names; if absent, asks one question for the
  decision in plain words and maps it to the catalogue.
- Catalogue and protocol: `references/catalogue.md` and
  `references/decision-protocol.md` in this skill.
- Context: `.bearing/company.json`, `docs/adr/`, `docs/product/PRD.md`, the
  HLD and the code; each is optional and reported as read or absent. A
  fact that changes the answer and is in none of them is asked for before
  the recommendation.
- ADR record: the repository's ADR convention, found the way `adr`
  finds it (an `.adr-dir` file, the location CLAUDE.md, AGENTS.md or the
  README names, then existing ADRs under `docs/adr/`, `docs/decisions/`,
  `docs/architecture/decisions/`, `doc/adr/`, `adr/` or `decisions/`):
  its directory, numbering, extension and headings. None found:
  `docs/adr/NNNN-<kebab>.md` from
  ${CLAUDE_PLUGIN_ROOT}/skills/adr/templates/adr.md. `adr` itself
  when the user wants the fuller record. Never a second numbering scheme
  beside an existing one.
- Decision log: `docs/decisions.md`; if absent, created from
  `templates/decisions.md` when the first decision is recorded, never
  just to hold a list of open keys.
- Question block: `templates/question.md` in this skill.

## Steps

1. Identify the candidate keys: from `$ARGUMENTS`, from the calling
   skill's list, or by reading the request for named technologies. Map
   each to a key in `references/catalogue.md`. A calling skill's list is
   the most it may need, not a questionnaire.
2. Load context that changes the answer before asking: `.bearing/company.json`
   (existing hosts, cloud, tracker), the ADR directory, `docs/product/PRD.md`
   and the HLD for scale, team size, compliance and budget hints, and the
   code for what is already in use. State the facts you found in one line
   each. Then sort every candidate key into exactly one bucket:
   - out of scope: what this task writes does not depend on it (a table
     change does not need an analytics store); drop it without a word on
     disk.
   - settled: an accepted ADR, a line in the request that states it as a
     given ("we use Postgres"), or the code already using it (a driver in
     `go.mod`, a provider in the Terraform) answers it. Cite that evidence
     and build on it; do not ask, and write no ADR or log row for it.
     A question about changing it ("should we move to GKE?") is answered
     here with the evidence and the fact that would change the answer,
     and it is recorded only when the recommendation is to change; "stay
     as we are" needs no new record, since the ADR that settled it still
     stands. Only a request to change it ("move us off X") reopens it.
   - open: needed and not settled. Only these are asked. A named
     technology the user wants but the repository does not use ("I want
     Kafka") is open, with their choice shown first. At most three per
     pass, the three that constrain the most (the catalogue order); list
     the rest in the output as waiting for the next pass, not on disk.
3. For each decision, one at a time, in the order the catalogue lists
   (the earlier ones constrain the later ones): print the question block
   from `templates/question.md`: the options (three to five, the user's
   own pick included), one line each on what it is good at and what it
   costs, the recommendation with the two or three reasons that decided
   it, the condition that would flip the recommendation, any fact the
   repository does not give that would change the answer (budget, who
   would operate it, a volume) with the assumption made about it, and
   the question. Run the checks in "Before recommending" first; their
   results are the reasons, not an appendix. Then stop and wait for the
   answer. Use the host's question
   tool when it exists, so the user picks from the list.
4. If the user picks against the recommendation, accept it in one
   sentence, note the consequence they are accepting, and continue.
   Do not argue twice.
5. Record only what the user decided in this conversation: one ADR per
   answered key, through `adr` when the user asks for the fuller
   record, else written here from the `adr` template (or the
   repository template) with the next number, context, the options shown,
   the decision and its consequences, status Accepted; and a row in
   `docs/decisions.md` from `templates/decisions.md` (key, choice,
   recommended, reason, ADR, date), plus a row in the ADR index only when
   the repository already keeps one (`docs/architecture/decisions.md` as
   `adr` step 6 writes it, or its own). Never create an index, a notes
   file or a directory the repository does not have: the ADR directory is
   the record. A key the user explicitly puts off
   gets a log row with status Deferred and the date. A key nobody
   answered is not a decision: when the user invoked this skill to
   decide it, write its ADR with status Proposed (awaiting the user) and
   no log row; when a building skill called it, write nothing and return
   it as awaiting. Never write an ADR or log row for a settled or
   out-of-scope key, and never name a person as the decider unless they
   answered. Print the count of keys decided, settled by the repository,
   awaiting the user and deferred by the user.
6. Return the decisions to the calling skill in the shape below so it can
   build with them.

## Before recommending

The checks a senior engineer makes and a fluent answer skips. Each one
that applies goes into the question block and the ADR.

- Size the win from the repository's numbers. Split the failure into its
  causes and compute the share the option can remove at best (share of
  the problem times the share it addresses) and what remains after a
  perfect fix. State the residual and put the flip condition on it. A
  cause of a different kind needs a different fix: fuzzy matching fixes
  typos, not synonyms or products that are not stocked.
- Convert load into the unit the option is sized in (per second at peak)
  and show the arithmetic. A number not in the repository is labelled an
  estimate, never stated as measured.
- Read where each number came from: environment, hardware, multiplier,
  window. Compare it with a recorded trigger exactly as the ADR words it
  (production, for a week); a staging test or a one-hour spike does not
  fire it, but say what it does tell you.
- Look in the code for a cheaper cause before new infrastructure: a
  connection opened per request, a blocking call inside an async handler,
  a vendor call inside the request, a missing index, a query per row.
- Count the load the option adds to what it shares (the same database at
  its measured CPU) and how that load is bounded.
- Test each claim made for the user's pick against how the thing works.
  Delivery guarantees stop at the system's edge: exactly-once in a broker
  covers its own reads and writes, not an HTTP call to a vendor.
- Asynchronous work (queues, retries, outboxes, webhooks) is not designed
  until it answers all of these:
  1. The enqueue commits with the state change (same transaction, or an
     outbox row); a publish after the commit loses messages.
  2. Where the consumer runs on the compute already chosen (a
     request-scoped container cannot host a loop left running after the
     response).
  3. A call to a vendor without an idempotency key that timed out is
     ambiguous: how it is resolved (the vendor's request id, a status or
     delivery-report check, no automatic resend) and who accepts the
     residual risk.
  4. The retry schedule and the terminal state when the window ends
     (failed, alerted, handed to someone); every sweep or re-enqueue
     honours that cutoff.
  5. The dispatch rate is capped at the vendor's limit, so the backlog
     built up during an outage does not arrive all at once on recovery.
  6. A message delivered twice to the consumer does nothing twice.
- Replacing an accepted decision: the new ADR says it supersedes the old
  one once accepted; the old ADR is not edited while the new one is only
  Proposed.

## Output contract

```
## Decisions (<N> decided, <S> settled by the repository, <A> awaiting the user, <D> deferred)
| Key | Choice | Recommended | Why | Evidence |
| database | PostgreSQL | (settled) | already in use | ADR-0001; go.mod pgx |
| messaging | Kafka | RabbitMQ | user chose Kafka for replay; accepts ops cost | ADR-0008 (Accepted) |
| cache | none | (settled) | ADR-0004 trigger not met: prod p95 90 ms < 250 ms | ADR-0004 |
| analytics store | (awaiting) | Postgres | 2M events a month, far under the threshold | ADR-0009 (Proposed) |
Next pass: search, observability
```

## Gotchas

- One question per turn. A wall of ten questions gets guessed answers.
- The recommendation is specific to the facts in step 2, never the
  catalogue's default alone. A fact the repository does not give that
  would change it (budget for a hosted service, who would operate a new
  service, whether data may leave the cloud account) is asked, or the
  assumption is stated.
- A deferred decision is written down as deferred with a date, not
  silently defaulted; a key nobody answered is reported as awaiting, not
  recorded as decided.
- An ADR for something the repository already does is noise: the
  evidence is the record. Cite it and move on.
- Managed services beat self-hosted for a small team unless a fact says
  otherwise (data residency, cost at scale, vendor lock-in the user
  refuses). Say which fact.
- Re-reading the ADR directory avoids re-asking; changing a recorded decision
  needs a new ADR that supersedes the old one.
