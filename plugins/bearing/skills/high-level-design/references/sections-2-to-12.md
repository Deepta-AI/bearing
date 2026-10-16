# high-level-design: filling sections 2 to 12

Read at step 3: what each section from users and flows to rollout and rollback must contain.

3. Fill sections 2 to 12 in template order:
- users and flows: numbered steps per actor, two or three flows;
- architecture: one mermaid diagram, then one paragraph per component
  (responsibility, owner, what it talks to and how);
- data: entities, store, retention, migrations implied; point at
  `data-model` for the full model;
- interfaces: every API, event and message, with the contract path
  (`api/openapi.yaml`, a schema file, an event sheet);
- external integrations: each third party on the runtime path, what
  the user sees when it is down, slow or rate limited, and where its
  credential lives; then "Deliberately not integrated", each with the
  reason;
- failure modes: one row per component with what fails, how it is
  noticed, what the user sees, how it recovers; an unknown cell is
  `UNDEFINED`;
- scaling and limits: expected load, the worst window (see Traps,
  peaks), first bottleneck, and the number at which the design stops
  working; a limit shared with other traffic (a provider plan, a
  pool, a table) is budgeted net of that traffic at the same hour,
  and a limit enforced per process is multiplied by the number of
  processes the design runs. When no design choice meets a
  requirement inside today's limits, say so with the arithmetic and
  name who must decide (a bigger plan under a new ADR, or a PRD
  change); never meet it silently by reinterpreting the requirement;
- security and privacy: auth model, authorisation per resource, PII
  touched, secrets needed;
- observability: logs, metrics, traces, alerts with runbook names;
- analytics: event sources, the store, the business question each
  answers and the reporting path, kept apart from the audit trail;
- rollout and rollback: flags, phases, migration order, how to back
  out at each phase, and what happens to work in flight at each
  cutover (queued jobs, pending rows, open sessions) going forward
  and going back. The back-out target exists today or is built in
  this plan; "fall back to the old path" when the old path was never
  built is not a back-out.
  Architecture, data, external integrations, scaling, security,
  observability, analytics and rollout each end with
  "**Risks this leaves open**" and at least one bullet.
