---
name: deployment-architecture
description: 'Documents how the system is deployed, with a diagram: environments, topology, scaling, backups, rollback, DR, each claim sourced. Use when asked "how is this deployed", "what runs where" or "document the deployment".'
argument-hint: "[--infra <path to infra repo or envs/ dir>]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(ls:*), Bash(find:*), Bash(mkdir:*), Bash(git log:*), Bash(python3 *skills/architecture-diagram/scripts/render.py*), Bash(python3 *skills/architecture-diagram/scripts/diagram_check.py*)
---

# deployment-architecture

This document is what the on-call engineer reads at 3 a.m. to know what
runs where, how big it is, and how to put it back. Every number and
name carries a `file:line` source; anything that comes from memory or a
conversation is prefixed "unconfirmed:" so nobody pages the wrong
cluster on the strength of a guess.

## Inputs

- Infra sources: looks in `--infra`, then `envs/*/`, `k8s/`, `helm/`,
  `terraform/`, compose files, the CI file and `.env.example`; if absent,
  `Dockerfile`, `Procfile`, the README's deploy section and `git log` for
  deploy commits; if still nothing, asks one question for the infra path
  or a description of the environments and writes every row from the
  description as `unconfirmed:`. Only no files and no description stops
  the skill: "pass --infra <path> or describe the environments".
- Diagram edges: derived here from manifests and env vars, as
  `architecture-diagram` does; that skill need not have run.
- Rollback facts: tested migration Downs from `db-migration` when the
  repository records them; if absent, the migration rollback cell is
  `UNDEFINED`.
- Template: `templates/deployment.md` in this skill.
- Drawing: `deployment_diagram` in `docs/architecture/architecture.json`
  and the renderer and gate in `architecture-diagram/scripts/`; if
  the model file is absent it is created with this view only.

## Steps

**Decisions first.** Before building, run `tech-decision` for the keys
cloud, compute, ingress, backups, ci. `tech-decision` asks only about the keys this task needs that no
accepted ADR, the request or the code already settles, one question at
a time, and records only what the user decides; a key still
awaiting an answer follows
${CLAUDE_PLUGIN_ROOT}/skills/tech-decision/references/decision-protocol.md.

1. Locate sources: `--infra` path or the repo; then `envs/*/`, `k8s/`,
   `helm/`, `terraform/`, `docker-compose*.yml`, `compose*.yaml`, the CI
   file (`.gitlab-ci.yml`, `.github/workflows/*.yml`), `.env.example`.
   Count files per kind. Zero infra sources: walk the fallbacks under
   Inputs and ask the one question; every claim that comes from the
   answer is `unconfirmed:`. Read `templates/deployment.md`.
2. Environments: dev, qa, prod. Per environment the URL (ingress hosts,
   values files), cluster and namespace, node or instance sizes, replica
   counts, resource requests and limits. Every cell is `value (file:line)`
   or `unconfirmed: <best guess>`.
3. Topology: one mermaid flowchart per environment that differs, with
   subgraphs for the network boundaries (public, private, data), boxes
   for ingress, services, workers, cron jobs, stores, queues and external
   SaaS. Edges from Service and Ingress manifests and env vars, as in
   `architecture-diagram`. Then the drawn version of production: write
   `deployment_diagram` in `docs/architecture/architecture.json` (tiers
   are network zones such as internet, public subnet, private network,
   managed services; groups are clusters, VMs or managed accounts; nodes
   are workloads and stores with replicas and size in `tech`; links carry
   the port and what flows), then run
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/architecture-diagram/scripts/render.py"`
   and
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/architecture-diagram/scripts/diagram_check.py"`
   until the check exits 0, and link
   `docs/architecture/diagrams/<Project>_DeploymentArchitecture_v<N>.svg`
   from the Topology section.
4. Network and ingress: ingress class, TLS termination, WAF or rate
   limiter, private endpoints, egress rules, what is reachable from the
   internet.
5. Scaling with numbers: HPA min, max and target per workload, DB
   connection pool sizes against the store's max connections, queue
   consumer counts, the first bottleneck.
6. Data stores and backups: per store the engine and version, size,
   backup mechanism and schedule, RPO and RTO, last restore test date.
   Missing means `unconfirmed: RPO/RTO not defined`.
7. Secrets and identity: the secret manager, how secrets reach a pod,
   workload identities and roles, who can read prod secrets, rotation.
8. CI to CD: stages from the CI file in order, the artefact and its tag
   scheme, promotion dev to qa to prod, and every manual gate (`when:
   manual`, protected environments, required approvals) named.
9. Rollback per component: mechanism (previous image tag, `helm
   rollback`, feature flag, migration Down via `db-migration`) and the
   exact command with placeholders. A component with no rollback path
   is written as `UNDEFINED`.
10. Disaster recovery: what a zone or region loss does, the failover
    steps, the last drill date. Cost: a placeholder table per component
    per environment with `unconfirmed` where no figure exists.
11. Write `docs/architecture/deployment.md` and print the output
    contract.

## Output contract

```
## Deployment architecture
Path: docs/architecture/deployment.md
Sources: N files (envs: a, k8s: b, compose: c, ci: d)
Environments: N   Workloads: N   Stores: N   Queues: N
Claims: N (sourced: S, unconfirmed: U)
Manual gates: N   Rollback UNDEFINED: K   Stores without RPO/RTO: K
Drawn: docs/architecture/diagrams/<Project>_DeploymentArchitecture_v<N>.svg (+ .png | PNG not written: <reason>)
diagram-check: <its counts line, verbatim>
Unconfirmed:
- <claim>: <where to confirm>
```

## Gotchas

- Compose is dev. Do not describe prod from a compose file; say
  "unconfirmed: from compose" when that is all there is.
- Never write a production hostname, IP or credential from memory. Copy
  it from a file with its line, or leave it unconfirmed.
- A rollback that needs a migration Down is only a rollback if the Down
  was tested (`db-migration`). Say which.
- Sizes without units and replicas without min and max are not numbers.
- No em dashes; diagrams in mermaid so they diff.
