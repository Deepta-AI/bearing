---
name: architecture-diagram
description: 'Draws the architecture from the code as it is: C4 and sequence diagrams in mermaid, SVG and PNG, every box sourced. Use when asked to "draw the architecture", "C4 diagram" or "sequence diagram".'
argument-hint: "[system or container] [--flow <route or use case>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(find:*), Bash(mkdir:*), Bash(git diff:*), Bash(git log:*), Bash(python3 *skills/architecture-diagram/scripts/render.py*), Bash(python3 *skills/architecture-diagram/scripts/diagram_check.py*)
---

# architecture-diagram

The diagram shows the system as the code says it is, not as the README
remembers it. Every box and edge names its source file. Anything inferred
from a name rather than a call site goes on the unconfirmed list, and the
list is part of the deliverable.

## Inputs

- Scope: looks in `$ARGUMENTS`; if absent, the whole repository.
- Services: looks in compose, k8s and helm files; if absent, `Dockerfile`,
  `Procfile`, `Makefile` run targets and the README's run section, each
  element marked unconfirmed.
- Modules: looks in `cmd/`, `internal/`, `pkg/`, `src/`, `app/`,
  `services/`; if absent, the directory layout two levels deep.
- Calls: grep of client libraries, queue names and env hosts; if absent,
  edges exist only where the user describes them, drawn dashed.
- Users: auth roles in the code and `docs/product/PRD.md`; if absent, one
  box `user (unconfirmed)`.
- Description: when the repository yields zero services and zero modules,
  asks one question for a description of the system and draws from it
  with every element on the unconfirmed list. Nothing after that stops
  the skill: "provide a repository with code or describe the services".
- Template: `templates/c4.md` in this skill.
- Model: `docs/architecture/architecture.json`, its `system_diagram`
  (the shape is in `scripts/render.py`'s header); if absent, step 9 writes it
  from this run's inventory. A repository with no code yet: the model
  comes from the HLD's "What gets built" table and the ADRs
  (`high-level-design`), every edge `"unconfirmed": true`.
- Renderer and gate: `scripts/render.py` and `scripts/diagram_check.py`
  in this skill, Python 3 standard library; the PNG needs Chrome or
  Playwright's Chromium (`CHROME_PATH`), otherwise the SVG is written
  alone and the report says why.
- Rendering: gstack `/diagram` when listed in the session; otherwise
  mermaid is the deliverable.

## Steps

**Revising.** When the output file already exists, this run is a
revision: read `${CLAUDE_PLUGIN_ROOT}/skills/adr/references/revision-protocol.md`
and follow it (version line, changes table, superseding ADR,
critic on changed sections, downstream list). Redraw only the diagrams
whose sources the reason for the revision touches (the files it names,
or `git diff` since the document last changed); every other diagram
block stays byte for byte, even when a fresh read of the code would draw
it differently. Such a drift goes in the output under Noticed, for the
user to ask for, never silently into the file. The changes table
compares each redrawn diagram's element and edge counts with v<n> and
names what appeared or went.

1. Scope from `$ARGUMENTS`: the system (default: the repository) and an
   optional container for the component view. Read `templates/c4.md`.
2. Inventory the sources and count each:
   - services: `docker-compose*.yml`, `compose*.yaml`, `k8s/**/*.yaml`,
     `helm/**/templates/*.yaml` (Deployment, StatefulSet, CronJob);
   - stores and queues: images and env vars naming postgres, mongo,
     clickhouse, redis, kafka, rabbitmq, nats, sqs;
   - modules: top-level packages under `cmd/`, `internal/`, `pkg/`,
     `src/`, `app/`, `services/`;
   - calls: grep for `http.NewRequest`, `httpx.`, `requests.`, `fetch(`,
     `axios`, `grpc.Dial`, and for producers and consumers of each queue
     named above; external hosts from `.env.example` and config files.
   Zero services and zero modules: ask the one question under Inputs and
   draw from the answer, every element unconfirmed.
3. Context (`C4Context`): the system, its users (from auth roles and the
   PRD), external systems (hosts in config). One `Rel` per real call.
4. Container (`C4Container`): one box per compose service or k8s
   workload, plus each store and queue. Edges come from env vars that
   point at a host and from client code; an edge with only a name behind
   it is drawn dashed and listed as unconfirmed.
5. Component (`C4Component`): for the chosen container (default: the one
   with most modules), one box per package; edges from imports. Skip
   packages under 30 lines and say so in the legend.
6. Sequence (`sequenceDiagram`): for each `--flow`, or the two busiest
   routes, follow handler to service to repository to external call.
   Add an `alt` branch wherever the code has one; a flow with no error
   handling on the path gets the note `no error branch in code`.
7. Write `docs/architecture/<kebab-scope>-c4.md`: the four diagrams, a
   legend (box and edge styles, what was skipped), a sources table
   (element, file, line) and the unconfirmed list. Then check the file:
   no sequence message, note or label contains `;` or `#` (Mermaid ends
   a statement at `;` and reads `#` as an entity code, so the diagram
   fails to render); write a comma or the word instead. Grep the written
   file for message lines (`->>`, `-->>`, `-)`, `Note`) holding either
   character and print "mermaid: N blocks, K unsafe characters"; K must
   be 0.
8. If the gstack `/diagram` skill is listed in this session, offer to
   render each mermaid block to `.excalidraw`, `.svg` and `.png` beside
   the file. Invoke it only on the user's yes.
9. The drawn diagrams. Write or update `system_diagram` in
   `docs/architecture/architecture.json` from steps 2 to 4: tiers left
   to right (client applications, edge, services, data and third
   parties), a group per deployable or workspace, a node per container,
   store, queue and external system with its `tech`, the component
   view's packages as the node's `modules`, `owns_store` on the node that
   owns a store, and one link per edge with a label saying what it
   carries and its kind (`sync`, `async`, `bulk`); an edge on the
   unconfirmed list gets `"unconfirmed": true`. Bump `version` when the
   model changed. Then run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/architecture-diagram/scripts/render.py"`
   and
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/architecture-diagram/scripts/diagram_check.py"`.
   They write `docs/architecture/diagrams/<Project>_SystemArchitecture_v<N>`
   and `_ArchitectureFlow_v<N>` (`.svg`, and `.png` where Chrome exists)
   and prove every node and link is drawn, no text overlaps or is
   clipped, no line crosses a node or a label and no two connections
   share a line. A failure is fixed in the model (a shorter name, a
   group split in two), never by editing the SVG; rerun both until the
   check exits 0. Link both images from the c4 file.

## Output contract

```
## Architecture: <scope>
Path: docs/architecture/<kebab-scope>-c4.md
Sources: N files (compose: a, k8s: b, packages: c, call sites: d)
Context: N systems, N users, N external
Container: N containers, N stores, N queues, N edges (unconfirmed: K)
Component (<container>): N components, N edges, skipped: K
Sequences: N (flows without error branch: K)
Unconfirmed: K
- <edge or element>: inferred from <what>
Mermaid: N blocks, 0 unsafe characters
Noticed: <drift in a diagram this revision did not touch> | none
Render: offered (/diagram) | mermaid only (/diagram not available)
Drawn: docs/architecture/diagrams/<Project>_SystemArchitecture_v<N>.svg (+ .png | PNG not written: <reason>), _ArchitectureFlow_v<N>
diagram-check: <its counts line, verbatim>
Revision: v<n> -> v<n+1>, sections changed C, ADRs superseded S, downstream D | v1 (new)
```

## Gotchas

- A compose file describes dev; k8s describes prod. When both exist,
  draw prod and note dev-only services in the legend.
- Do not draw an edge because two services "obviously" talk. If no
  client call, env var or queue name links them, it is unconfirmed.
- Mermaid C4 ignores unknown element types silently. Use only the
  shapes in `templates/c4.md`.
- Do not redraw by hand what `--flow` can trace; a sequence with no
  file references is a guess.
- No em dashes; each diagram in its own fenced `mermaid` block so it
  diffs.
- The SVG is generated. Editing it by hand is lost on the next render and
  skips the gate; change `architecture.json` and render again.
- A connection label says what the connection carries ("SQL reads and
  writes", "order events"), not the protocol alone; the protocol goes in
  the label only when it is the point ("REST over HTTPS").
