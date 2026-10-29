# Every Bearing skill, explained

The table is generated from each skill's frontmatter (`make docs`). The
notes below it are written by hand.

Every skill is independent: it declares its inputs in an `Inputs` section,
looks for the upstream artifact first, and when that is missing it asks
for the input or derives it from the code instead of stopping. Each skill
carries its own copy of every template it fills, so it works in a
repository that was never scaffolded. Other skills are named only as the
fuller path, never as prerequisites.

Every skill is reached two ways: ask in your own words and Claude loads
the one whose description matches, or type it as `/<plugin>:<name>` (for
example `/bearing:merge-request`, `/bearing-backend:go`, `/bearing-apps:react`;
the Plugin column says which). On a machine with many skill packs
Claude Code may list some skills by name only; see
[Keep the skill listing lean](INSTALL.md#keep-the-skill-listing-lean).
The eight subagents are `bearing:reviewer`, `bearing:verifier`,
`bearing:security-auditor`, `bearing:explorer`, `bearing:test-writer`,
`bearing:doc-writer`, `bearing:critic` and `bearing:prd-drafter`; the skills start them.

<!-- skills-table:start -->
| Skill | Plugin | What it does | Use when |
| --- | --- | --- | --- |
| `ab-experiment` | bearing | Designs and analyses an A/B test: hypothesis, metrics, sample size, stopping rule | asked to "A/B test this" or "is it significant" |
| `accessibility` | bearing | Audits and fixes accessibility to WCAG 2.2 AA on web and mobile | asked about "a11y", "WCAG" or "screen reader" support |
| `adr` | bearing | Records a decision already made as a numbered ADR: context, options, outcome | asked to "write an ADR" or "record this decision" |
| `analytics-events` | bearing | Designs the analytics event sheet, wires one tracking module, audits code against it | asked to "add an event" or "audit tracking" |
| `android` | bearing-apps | Android house rules (Kotlin, Compose, Hilt, Room, Gradle); load before changing Android code | asked for "a Room DAO" or "a Hilt module" |
| `api-versioning` | bearing | Versions and retires API endpoints with Deprecation and Sunset headers | asked to "deprecate an endpoint" or "version the API" |
| `app-store-release` | bearing | Prepares an App Store or Google Play submission: builds, listing, privacy, rollout | asked to "submit to the App Store" or "app rejected" |
| `architecture-diagram` | bearing | Draws the architecture from the code: C4 and sequence diagrams in mermaid | asked to "draw the architecture" or "C4 diagram" |
| `auth` | bearing | Builds authentication and authorisation: sessions, passkeys, OAuth, roles, tenancy | asked to "add login" or "roles and permissions" |
| `autopilot` | bearing | Runs unattended from one requirement to a prepared merge request for review | asked to "autopilot this" or "run it end to end" |
| `background-jobs` | bearing | Jobs that must not be lost or run twice: cron jobs, queues, workers, retries, an outbox after a commit | asked for a "worker" or a "queue" |
| `backlog` | bearing | Turns PRD requirements into epics and Given-When-Then user stories | asked to "build the backlog" or "break down the PRD" |
| `branch-review` | bearing | Reviews a branch, MR or patch with stack checklists, verified findings and a verdict | asked to "review the MR" or "look over my changes" |
| `ci-pipeline` | bearing | Generates or fixes the CI pipeline (GitLab CI or GitHub Actions), every job a make target | asked to "add CI" or "set up the pipeline" |
| `client-deliverables` | bearing | Builds the client documentation pack as Markdown, CSV and versioned Word | asked to "build the client pack" or "export the docs to Word" |
| `client-handover` | bearing | Writes the end-of-engagement client handover pack: access, deploy, runbooks, sign-off | asked to "prepare the handover" or "hand this over" |
| `cloud-cost` | bearing | Reviews the cloud bill read-only: spend by service, top lines, cost per request, proposed cuts | asked for a "cost review" or about "FinOps" |
| `company-attribution` | bearing | Sets who owns a repository: LICENSE, NOTICE, CODEOWNERS, SECURITY.md and package metadata | asked to "add a licence" or "who owns this code" |
| `computer-vision` | bearing-genai | Image and scan features: check or classify photos, read fields from scans, find defects | asked to "classify images" or "extract from scans" |
| `data-model` | bearing | Designs the data model from the stories: schema.sql, data dictionary and ERD | asked to "design the data model" or "draw the ER diagram" |
| `data-pipeline` | bearing-backend | Data pipeline house rules (dbt, Airflow, sqlfluff, backfills); load before changing warehouse code | asked for "dbt models" or "a backfill" |
| `database` | bearing | PostgreSQL, ClickHouse or MongoDB: indexes, slow queries, EXPLAIN, which store fits | asked about "an index" or "a slow query" |
| `dataset-generation` | bearing-genai | Generates eval, training or preference data from a real seed, deduped and audited | asked to "make synthetic data" or "we need more examples" |
| `db-migration` | bearing | Writes a database migration with a tested down step and lock-safety notes | asked to "add a migration" or "change the schema" |
| `definition-of-done` | bearing | Checks a branch or ticket against the Definition of Done with evidence per item | asked "am I done" or "ready to merge?" |
| `dependency-audit` | bearing | Audits dependencies for vulnerabilities and old versions, applies safe upgrades with tests | asked to "audit dependencies" or "bump deps" |
| `deployment-architecture` | bearing | Documents how and where the system is deployed: environments, topology, backups, DR | asked "what runs where" or "how is it deployed" |
| `design-critique` | bearing | Scores a UI design or prototype at three widths and both themes, with an AI-slop check | asked to "critique this design" or "score this" |
| `design-directions` | bearing | Produces three different visual directions over the real screens and records the pick | asked for "design directions" or "which look" |
| `design-system` | bearing | Turns a design direction into oklch tokens, stack themes, a component contract and a lint | asked to "make design tokens" or "lint colours" |
| `docs-drift` | bearing | Finds docs that drifted from the code (dead links, paths, make targets, env vars) and fixes them | asked to "check the docs" or "docs drift" |
| `doctor` | bearing | Checks this machine and repo are set up for Bearing (packs, hooks, rules), with fixes | asked to "check my setup" or "is it installed" |
| `estimate` | bearing | Estimates a backlog in points and hours, with assumptions and a confidence range | asked "how long will this take" or "size the stories" |
| `explain-codebase` | bearing | Explains how a repo or feature works, read-only, citing path:line for each claim | asked "how does this work" or "where is X handled" |
| `feature-flags` | bearing | Adds or removes a feature flag: default off, owner, removal date, tests for both states | asked to "add a feature flag" or "remove the flag" |
| `feature-patterns` | bearing | Plans a common feature mechanism before code: uploads, search, realtime, caching, rate limits | asked to "add file uploads" or "add realtime" |
| `flutter` | bearing-apps | Flutter and Dart house rules: Riverpod, go_router, dio, freezed, flavours, flutter_test | writing "Flutter widgets" or "Dart code" |
| `gate-audit` | bearing | Audits every gate (CI jobs, git hooks, make check) for passing on empty input | asked to "audit the gates" or "is this check real" |
| `genai-design` | bearing-genai | Designs a GenAI solution before code: metric, cheaper option, model, cost, risks, evals | asked "RAG or agent" or "design the LLM feature" |
| `git-hooks` | bearing | Installs or repairs the committed git hooks and sets core.hooksPath | asked to "install the git hooks" or "set up hooks" |
| `go` | bearing-backend | Go house rules: net/http, pgx, sqlc, goose, slog, table-driven tests. Load before changing Go | asked for "a Go handler" or "sqlc queries" |
| `harness-setup` | bearing | Sets up a repo for another coding agent (Cursor, Codex, Gemini CLI, Copilot): rules, hooks, skills | asked to "set up Cursor" or "add Codex" |
| `health-checks` | bearing | Builds /healthz and /readyz with dependency checks, synthetic journeys, uptime alerts | asked to "add health checks" or "uptime monitoring" |
| `high-level-design` | bearing | Writes a High Level Design: goals and non-goals, architecture, data, failure modes, rollout | asked for an "HLD" or "system design" |
| `i18n` | bearing | Internationalises an app: string catalogs, ICU plurals, locale formatting, RTL, missing keys | asked to "add a language" or "support RTL" |
| `incident` | bearing | Runs a live incident as scribe: severity, UTC timeline, roles, comms; never remediates | "we have an outage" or "declare an incident" |
| `infra` | bearing-backend | Infrastructure house rules: Terraform modules, remote state, tflint, Trivy, kustomize | asked about "remote state" or "a kustomize overlay" |
| `ios` | bearing-apps | iOS house rules: Swift 6, SwiftUI, Observation, Concurrency, SwiftData, Swift Testing | asked for "an iPhone screen" or "SwiftData models" |
| `learn` | bearing | Lists, adds and proposes Bearing learnings kept on this machine (opt-in) | asked "what has Bearing learned" or "remember this for next time" |
| `license-compliance` | bearing | Checks open-source licences: CycloneDX SBOM, licence inventory against policy, notices | asked for an "SBOM" or a "licence check" |
| `llm-agent` | bearing-genai | Builds an LLM agent on the Anthropic SDK: tools, bounded loop, memory, guardrails, kill switch | asked to "build an agent" or "multi-agent" |
| `llm-eval` | bearing-genai | Evaluates an LLM feature: golden set, code graders, LLM judge, CI regression gate | asked to "build an eval set" or "evaluate the model" |
| `llm-fine-tuning` | bearing-genai | Fine-tunes an open model when prompting and RAG fall short: LoRA, DPO, distillation | asked to "fine-tune a model" or "train on our data" |
| `llm-gateway` | bearing-genai | One gateway for every LLM call: find each call, model tiers, retries, caching, cost per feature | asked about "AI spend" or "LLM costs" |
| `llm-guardrails` | bearing-genai | Secures LLM chatbots and agents: prompt injection, jailbreaks, PII in prompts, tool permissions | asked for "guardrails" or "LLM safety" |
| `load-test` | bearing | Writes k6 load tests from the SLOs with failing thresholds; refuses production | asked to "load test" or "soak test" a service |
| `logging` | bearing | Adds structured logging: one logger, request id at the edge, shared fields, redaction | asked to "add logging" or "improve the logs" |
| `low-level-design` | bearing | Writes a Low Level Design for one HLD component: modules, types, errors, queries, MR-sized work | asked for an "LLD" or "detailed design" |
| `mcp-server` | bearing-genai | Builds an MCP server in Python or TypeScript with tested tools and auth | asked to "build an MCP server" or "expose this as MCP tools" |
| `merge-request` | bearing | Prepares the MR for the current branch: gate run, commit audit, diff summary, description | asked to "prepare the MR" or "write the MR text" |
| `model-routing` | bearing-genai | Picks the cheapest LLM model or cascade per feature that still passes its eval | asked "which model should we use" or "cut our LLM bill" |
| `motion-design` | bearing | Writes motion tokens and builds an animation with a reduced-motion path | asked to "add animation" or "animate this" |
| `new-repo` | bearing | Creates a new repository for one stack with Makefile, CI, hooks, CLAUDE.md and AGENTS.md | asked to "create a repo" or "scaffold a service" |
| `new-skill` | bearing | Creates a new Bearing skill in the kit checkout with house sections, lints and an eval | asked to "add a skill" or "make this a skill" |
| `nextjs` | bearing-apps | Next.js house rules (App Router, server components, actions). Load before Next.js code | asked for "an App Router page" or "a new route" |
| `node` | bearing-backend | Node house rules (TypeScript, Fastify, Zod, Drizzle, vitest). Load before Node backend code | asked for "a Fastify route" or "a Node API" |
| `observability` | bearing | Wires OpenTelemetry traces and metrics, trace ids in logs, dashboards, SLOs and alerts | asked to "add observability" or "set up tracing" |
| `on-call` | bearing | Sets up on-call: rotation, escalation, alert routing by severity, error budget policy | asked "who gets paged" or "how do we escalate" |
| `onboard-repo` | bearing | Brings an existing repository onto team conventions without overwriting its files | asked to "onboard this repo" or "adopt the standard" |
| `openapi-spec` | bearing | Designs or audits the OpenAPI 3.1 contract, generates API docs, counts route drift | asked to "write the OpenAPI spec" or "check the spec" |
| `performance` | bearing | Finds and fixes slowness by profiling first, with before and after numbers | asked "this is slow", "profile this" or "p95 is high" |
| `postmortem` | bearing | Writes a blameless postmortem: impact, UTC timeline, root cause, owned follow-ups | asked for a "postmortem", "RCA" or "write up the outage" |
| `prd` | bearing | Turns a brief, notes or ticket into a PRD of numbered testable requirements and open questions | asked to "write the PRD" or "spec this out" |
| `privacy-review` | bearing | Reviews personal data handling: data map, retention, deletion, a DPIA | asked about "GDPR", "personal data" or "delete my account" |
| `prompt-registry` | bearing-genai | Keeps prompts as versioned files with typed variables, fixture tests and scores | asked to "write the system prompt" or "version prompts" |
| `prose-lint` | bearing | Lints prose (docs, MR text, commits, UI copy) for em dashes and AI filler | asked to "check the prose" or "lint the README" |
| `python` | bearing-backend | Python house rules (FastAPI, Pydantic v2, SQLAlchemy, uv, pytest). Load before Python code | asked for "a Celery task" or "a Python service" |
| `rag` | bearing-genai | Builds RAG on pgvector: ingestion, chunking, a retriever that cites sources, metrics | asked to "add RAG" or "answer from our documents" |
| `react` | bearing-apps | React house rules (React 19, Vite, TanStack Query, shadcn/ui). Load before React code | asked for "a React component" or "a query hook" |
| `react-native` | bearing-apps | React Native house rules (Expo, expo-router, NativeWind). Load before Expo code | asked for "an Expo screen" or "an EAS build" |
| `refactor` | bearing | Refactors without changing behaviour: tests green first, one mechanical change per commit | asked to "refactor this" or "clean this up" |
| `release` | bearing | Prepares a release: version from commits, CHANGELOG section, version bump, tag commands | asked to "cut a release" or "bump the version" |
| `resilience-testing` | bearing | Tests claimed failure modes: fault injection, restore drills, DR tests with RTO and RPO | asked about "chaos testing" or "restore drill" |
| `runbook` | bearing | Writes the runbook for one alert: meaning, diagnosis, remediation, rollback, escalation | asked to "write a runbook" or "document this alert" |
| `screen-design` | bearing | Designs every screen in every state, desktop and phone, as clickable mockups | asked to "design the screens" or "show every state" |
| `secrets` | bearing | Handles secrets without seeing values: inventory, rotation, leak response, gitleaks | "a key was committed" or asked to "rotate the secret" |
| `session-handoff` | bearing | Saves session state for the next session on this branch: next steps, blockers, questions | asked to "write a handoff" or "pause here" |
| `simplify-code` | bearing | Deletes code a change does not need (dead code, one-use abstractions), tests green | asked to "simplify this code" or "cut the bloat" |
| `speech` | bearing-genai | Builds transcription, text-to-speech or voice agents, measured by WER and latency | asked to "build a voice agent" or "speech to text" |
| `spike` | bearing | Runs a timeboxed spike on one question with throwaway code and a written answer | asked to "spike this" or "investigate whether" |
| `start-task` | bearing | Starts a ticket: branch from the right base with the task id, notes, criteria restated | asked to "pick up this ticket" or "start TASK-142" |
| `tabular-ml` | bearing-genai | Predictive models on tables or event history: churn and risk scores, demand forecasts, anomalies | asked to "predict" or "forecast" from data |
| `task-report` | bearing | Writes the end-of-task report: Changed, Verified, Not done, Noticed, with evidence | asked to "write up what you did" or "report back" |
| `tech-debt` | bearing | Keeps the debt register in docs/DEBT.md from TODOs, lints and skipped tests, ranked by cost | asked about "tech debt" or "the debt register" |
| `tech-decision` | bearing | Compares technology options, recommends, lets the user decide, records an ADR | asked "which cloud" or "what stack should we use" |
| `test-automation` | bearing | Sets up or extends automated tests (Playwright, Maestro, pytest), one per TC id | asked to "automate the test cases" or "set up Playwright" |
| `test-cases` | bearing | Writes TC-numbered manual test cases and a test plan from acceptance criteria | QA needs "the test cases" or "the manual test plan" |
| `test-heal` | bearing | Fixes failing or flaky tests: classifies each failure, heals drift, quarantines flakes | asked to "fix the flaky tests" or "heal the tests" |
| `test-run` | bearing | Runs every test suite into one report: failures at file:line, slowest, flaky, coverage | asked to "run the tests" or "what is failing" |
| `themes` | bearing | Adds design system themes (dark, high contrast, brand, tenant) with contrast checks | asked to "add dark mode" or "theme for a tenant" |
| `threat-model` | bearing | Writes a STRIDE threat model before code: assets, boundaries, threats, mitigations | asked to "threat model this" or "STRIDE analysis" |
| `traceability` | bearing | Builds the requirements traceability matrix to stories, tests and commits, counting gaps | asked "is everything traced" or "what is untested" |
| `tracker-sync` | bearing | Creates and updates tickets in Jira, GitLab or GitHub, moves status, links MRs | asked to "create the tickets" or "sync to Jira" |
| `upgrade-tools` | bearing | Upgrades every installed Claude Code plugin and skill pack, versions before and after | asked to "update the plugins" or "upgrade the skills" |
| `ux-flows` | bearing | Maps UX flows: screens tied to stories, every state with copy, no dead ends | asked to "map the user flows" or "what screens do we need" |
| `vapt-report` | bearing | Writes the release VAPT report from scanner findings and the threat model, ship or block | asked for a "VAPT report" or "security sign-off" |
| `verify-deploy` | bearing | Checks one environment after a deploy: readiness, health, version, smoke, synthetics | asked to "verify the deploy" or "check qa" |
| `webhooks` | bearing | Builds webhooks: inbound with signatures and idempotency, outbound with retries | asked to "add a webhook" or "verify signatures" |
| `workflow` | bearing | Says where the work stands (repository, branch, diff) and which skill comes next | asked "what should I do next" or "which skill do I use" |
<!-- skills-table:end -->

## Meta

- **workflow** is the front door. It reads the branch, the diff and
  the stack, places you on the stage map and names the next skill.
- **doctor** verifies the machine and the repository. It diagnoses;
  `onboard-repo` and `install.sh` repair.
- **upgrade-tools** updates Bearing, Superpowers, gstack and GSD Core.
- **new-skill** scaffolds a new Bearing skill, runs the lints, hands
  it to skill-creator for evals against a no-skill baseline, and updates
  this file and the changelog.
- **harness-setup** sets a repository and a machine up for Cursor, Codex,
  Gemini CLI, Copilot, OpenCode, Windsurf, Cline, Zed or Kiro from the
  same standard: rule conversion, instruction pointers, the vendored guard
  (`.bearing/bin/brg-guard`) with hook adapters under `.bearing/hooks/`, and skill
  installation.

## Product and discovery

- **prd** normalises any brief into `docs/product/PRD.md` with
  numbered `REQ-nnn` statements; it never invents, it marks inferred.
- **backlog** turns statements into epics and `US-` stories with
  `AC-` criteria, a coverage matrix and user flows; `coverage_check.py`
  computes coverage from the criteria and fails on any gap. Statements are judged and combined, never one story per line.
- **estimate** sizes the backlog with assumptions, a dependency graph
  and a phase plan; refuses stories without criteria.
- **tracker-sync** creates and updates tickets in whichever tracker
  `BEARING_TRACKER` names (Jira, GitLab issues, GitHub issues, any server
  speaking the REST tracker protocol, or none) through `plugins/bearing/bin/brg-tracker`,
  syncs the backlog, and posts branch, MR, commits, tests and ADR on the
  ticket. With `none` every ticket step is skipped with a note. The REST
  tracker is one adapter behind it (`BEARING_TRACKER=rest`), not a skill
  of its own. Configuration, key shapes and the protocol:
  `docs/TRACKERS.md`.
- **spike** runs a timeboxed investigation: a written question, a
  timebox, a stop condition, throwaway code under `.scratch/` or a spike
  branch that is never merged, and a result under `docs/spikes/` with a
  recommendation (adopt, reject, narrower spike).
- **ab-experiment** designs and analyses an A/B or feature experiment on
  top of a feature flag: hypothesis, primary and guardrail metrics, MDE and
  sample size, exposure events, stopping rules, the read-out.

## Architecture and design

- **tech-decision** is the technology decision protocol: for cloud, compute,
  messaging, databases, IaC, CI, observability, auth, API style,
  frameworks, LLM providers and more, it shows the options with a
  recommendation and the reasons, asks one question at a time, lets you
  decide, and records an ADR and a row in `docs/decisions.md`. Every
  building skill runs it first.
- **adr** records a decision with the rejected options.
- **architecture-diagram** draws C4 and sequence diagrams from the
  code as it is, in mermaid, with gstack `/diagram` for rendering.
- **high-level-design** and **low-level-design** write the high and low level designs; every
  claim sourced or marked as an assumption; failure modes never blank.
- **openapi-spec** designs the OpenAPI 3.1 contract before code and
  reports drift between spec and routes afterwards.
- **data-model** produces the ERD and per-store schema with index
  rationale and the migration plan.
- **deployment-architecture** documents environments, topology,
  scaling, backups, rollback and DR from the infra and CI files.
- **threat-model** runs STRIDE per feature with mitigations mapped to
  stories; `vapt-report` cites its threat ids in the release report.
- **explain-codebase** maps a repository or subsystem, reads only, every claim
  as `path:line`: entry points, module graph, one request's flow, the ten
  files that matter, conventions in use with match, drift or unclaimed
  per convention.
- **api-versioning** versions and retires an API: URL, header or
  additive-only versioning with reasons, Deprecation and Sunset headers, a
  consumer inventory, a removal gate counted from logs, a breaking-change
  checklist.
- **auth** designs authentication and authorisation: session or token
  with reasons, passkeys, OAuth and OIDC, IDOR checks, RBAC or ABAC,
  tenant isolation, token rotation, a permission matrix the tests read.
- **background-jobs** designs background work with failures designed in: queue,
  cron or outbox with reasons, idempotency keys, retry with backoff and
  jitter, dead letters, visibility timeouts, graceful shutdown.
- **webhooks** builds webhooks both ways: inbound with constant-time
  signature checks, a replay window, idempotent handlers and a fast ack;
  outbound with an event catalogue, retries, dead letters and a consumer
  dashboard.
- **feature-patterns** is the patterns library (uploads, search, realtime,
  cache, rate limit, payments, notifications, multitenancy): each with a
  decision, data model, failure modes and tests; loads one and writes the
  ADR.

## Design

The design lane is spec-first and slop-free: every skill reads the flows
or the spec, applies the doctrine in `design-directions/references/design-doctrine.md`
(no default AI palettes, no Inter or Space Grotesk display faces, no
emoji markers, real content, both themes, reduced motion, visible focus),
and iterates with the user.

- **ux-flows** turns a spec into a screen inventory, a state table
  per screen, a journey storyboard, navigation and flow diagrams, and a
  dead-end check that must come back zero.
- **design-directions** produces three genuinely different HTML
  variants (different display face, palette temperature and layout
  rhythm, checked by the swapped-headline test), a comparison board with
  screenshots, and a feedback round that writes `approved.json`. You
  choose; a remix is a valid choice.
- **design-system** turns the chosen direction into tokens as code
  (`tokens.json` in oklch, CSS and Tailwind, React Native, Compose,
  SwiftUI bindings), a component contract, a gstack-compatible DESIGN.md
  and a `make design-lint` gate.
- **screen-design** renders every screen with every state as an HTML
  prototype in the repository, gates every inventory state with
  `states_check.py`, screenshots it at three widths in both themes, and
  iterates with redlines for the developer.
- **themes** layers themes on the system as role overrides only (light,
  dark, high contrast, brand, tenant), validates contrast on every pair,
  and generates a side-by-side preview.
- **motion-design** writes the motion spec and tokens and implements the
  patterns: flow transitions, micro-interactions, hero and banner moments
  with scripted timelines, ambient motion within a budget, always with a
  reduced-motion path.
- **design-critique** reviews prototypes or a URL against a weighted
  checklist with an AI-slop detector, scores, fixes with approval, and
  re-scores; `evidence.py` shoots three widths in light and dark and fails
  when a dark theme did not apply. The workflow runs it while only prototypes exist; once the app runs in
  a browser the workflow switches to gstack `/design-review`.

## Repository lifecycle

- **new-repo**, **onboard-repo**, **ci-pipeline**, **git-hooks** create or
  bring a repository onto the standard: files, pipeline, hooks.
- **company-attribution** attributes a repository to an organisation: the company
  profile every other skill reads, the LICENSE (proprietary, Apache-2.0,
  MIT or custom), NOTICE, CODEOWNERS handles, security contact, package
  metadata and bundle ids. The kit itself names no company.

## Platform concerns

- **observability** wires OpenTelemetry, a local stack, dashboards,
  alert rules with runbooks, and SLOs.
- **logging** adds structured, request-id logs at every boundary and
  HTTP request logging behind `LOG_HTTP` and `LOG_HTTP_BODIES`.
- **health-checks** builds `/healthz`, `/readyz` with dependency
  checks, synthetic journey probes, uptime monitoring and health alerts.
- **analytics-events** designs and wires analytics events for the app, a
  feature or one event, and audits code against the sheet.
- **i18n** sets up string catalogs, ICU plurals, Intl formatting, RTL
  and a missing-key gate.
- **feature-flags** adds or removes a flag with an owner, a removal
  task and tests for both states.
- **dependency-audit** audits and upgrades dependencies with a Renovate config.
- **secrets** keeps secret hygiene: an inventory in
  `docs/security/SECRETS.md`, rotation per secret type, the leak response
  (revoke, rotate, scrub, audit, notify), a gitleaks pre-commit check.
- **license-compliance** produces open-source compliance: a CycloneDX SBOM,
  a licence inventory gated by an allow and deny policy with counts,
  `NOTICE-THIRD-PARTY.md`, a provenance note.
- **privacy-review** runs the privacy review that ends in mechanisms: a data
  map (what, where, why, basis, retention) from the data model or a
  schema grep, deletion wired to it, DSAR paths, a DPIA, a PII lint.

## Task flow

- **start-task** starts a task branch with the state file.
- **session-handoff** writes session state; the SessionStart hook prints it.
- **task-report** produces Changed, Verified, Not done, Noticed.
- **definition-of-done** walks the Definition of Done with evidence and a verdict;
  a bug fix's test is proven red without the fix in a throwaway worktree.
- **merge-request** prepares the merge request or pull request; the engineer
  pushes.
- **release** writes the changelog, bumps the version and prints the
  tag. With `--package` it ships a library, SDK or CLI: API diff since the
  last tag, semver from the diff, pack check, README install check,
  workspace release order and provenance; prints the publish command,
  never runs it.
- **app-store-release** prepares an App Store or Play submission: build
  numbers, listing, screenshots, tracks, phased rollout with halt rules,
  privacy forms, notes, a rejection playbook; every store command printed.
- **refactor** restructures without changing behaviour: tests green
  first, one mechanical transform per commit, `make check` between, a
  diff ceiling, a stop when behaviour changes.
- **tech-debt** keeps the technical-debt register in `docs/DEBT.md`
  (interest, principal, trigger, owner) seeded from TODO markers,
  suppressed lints and skipped tests, counted; the review ranks by
  interest.

## Quality

- **test-cases** derives scenarios and `TC-` cases from criteria,
  then designs each case's oracles separately (`ui:`, `data:`, `not:`,
  `effect:`, `inv:`); `cases_check.py` gates coverage and oracles.
- **test-automation** creates the suite per stack and generates tests
  named by TC id, one assertion per oracle; the type check and
  `ref_check.py` reject invented ids, names and routes; a failing
  generated test is handed on, never patched.
- **test-run** runs every suite present (unit, integration, e2e, UI,
  load, synthetic) through the runner's machine-readable output and writes
  one pass/fail report with failures at file:line, the slowest ten, flaky
  candidates, coverage and the TC and story ids; a suite that did not run
  is listed, never passed.
- **test-heal** classifies each failure with evidence (locator drift,
  timing, data, environment, real regression), heals only the first four
  through stable locators, condition waits and the builders, leaves a
  regression red and filed, proves a timing or data heal with 50 passes
  of 50, and quarantines only the flaky with a task id and a deadline in
  `docs/testing/quarantine.md`.
- **load-test** writes k6 tests with thresholds; never against prod.
- **performance** measures, profiles, fixes and measures again with the
  stack's profiler (pprof, py-spy, --cpu-prof, clinic, Lighthouse,
  macrobenchmark, Instruments); delivers a before and after number under
  `docs/performance/`.
- **resilience-testing** proves the HLD failure-mode table holds: a fault
  plan with expected behaviour, a dated restore drill, a DR test with
  measured RTO and RPO, chaos tooling; observed against expected, counted.
- **accessibility** audits and fixes WCAG 2.2 AA and mobile a11y.
- **branch-review** runs gstack `/review` with the stack checklists (the
  read-only reviewer without gstack) and sends every Critical and High to
  an independent `verifier`.
- **vapt-report** writes the VAPT report from claude-security or `/cso`
  findings, tied to the threat model, with a release decision.
- **gate-audit** proves every gate fails on empty input.
- **prose-lint** removes em dashes, filler and attribution.
- **traceability** builds the REQ to US to AC to TC to commit to
  ticket to docs matrix and fails on any gap.
- **db-migration** scaffolds migrations with a tested Down.

## Operate

- **runbook** per alert, **incident** during, **postmortem**
  after.
- **on-call** sets up on-call: rotation, escalation, alert routing by
  severity, an error-budget policy with the freeze rule, handover notes, a
  weekly review, and a check that every paging alert has a runbook.
- **cloud-cost** reviews cloud cost: attribution per service and environment
  from a billing export or the provider CLI, the top ten spend lines, unit
  economics, cuts, a monthly cadence.
- **client-handover** produces the client handover pack under
  `docs/handover/` at the end of an engagement: overview, environments,
  access inventory without values, deploy, runbooks, debt, licences, a
  sign-off verdict.

## GenAI

- **genai-design** designs the approach for a problem statement
  (prompt, retrieval, agent, fine-tune) with cost, risk and eval plan.
- **prompt-registry** keeps prompts in a versioned registry with tests and an
  eval score per version.
- **llm-agent** builds an agent of a chosen type (tool-user, planner,
  router, supervisor, workflow, background, human-in-the-loop) with a
  typed tool registry, bounded loops, memory rules and a kill switch.
- **rag** builds retrieval of a chosen type (naive, hybrid, reranked,
  hierarchical, graph, agentic, SQL, multimodal, long-context) with
  ingestion, pgvector schema, citations and evals.
- **llm-eval** defines metrics, builds the golden set and graders,
  runs `make eval` and gates regressions in CI.
- **llm-fine-tuning** decides whether to fine-tune, prepares data, picks
  the recipe (SFT with LoRA, preference tuning, distillation) for open
  models, checks the GPU, proves the pipeline with a smoke run, serves the
  adapter with vLLM behind the gateway and writes the model card; the run
  itself can go to `huggingface-llm-trainer` or `trl-training`.
- **mcp-server** builds MCP servers (Python or TypeScript) and clients with
  schemas, auth, tests and the harness registration; the workflow runs it
  for "tools for models".
- **llm-guardrails** adds input, tool-call and output safety with a policy
  file and adversarial fixtures.
- **llm-gateway** routes every model call through one module with
  retries, caching, cost accounting, tracing and a kill switch, and checks
  that every provider the product calls (Anthropic, OpenRouter, a vLLM
  endpoint) has its key before a demo or deploy.
- **speech** builds transcription, text-to-speech and real-time voice
  agents, choosing the engine by WER per language on the product's own
  audio and holding the agent to a per-stage latency budget.
- **computer-vision** builds VLM, trained, anomaly and document vision features
  with group-safe splits, AUROC or mAP, and a threshold set from what a
  miss and a false reject cost.
- **tabular-ml** builds classical ML (churn, scoring, forecasting, metric
  anomalies) with a leakage check on the split, a baseline the model must
  beat, calibration, explanations and drift monitoring.

## Stacks

Each stack skill loads itself when you work on matching files and holds
the guidelines, review checklist, rules file and scaffold templates. The
stack skills ship in two optional plugins: `bearing-backend` (go, python,
node, data-pipeline, infra) and `bearing-apps` (react, nextjs,
react-native, flutter, ios, android). Without the plugin a stack needs,
`new-repo`, `onboard-repo`, `ci-pipeline` and the review checklists name
it with the install command instead of failing.

- **react** (`react-web`), **nextjs** (`next-app`), **node**
  (`node-api`), **go** (`go-api`, `go-cli`), **python** (`python-api`,
  `python-cli`), **data-pipeline** (`data-pipeline`), **react-native**
  (`react-native`), **flutter** (`flutter-app`), **android** (`android`),
  **ios** (`ios`) and **infra** (`infra`): thirteen scaffold ids from
  eleven stack skills. **database** holds the store conventions every
  server stack shares and scaffolds nothing.
