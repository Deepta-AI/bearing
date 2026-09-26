# Every Bearing skill, explained

The table is generated from each skill's frontmatter (`make docs`). The
notes below it are written by hand.

Every skill is independent: it declares its inputs in an `Inputs` section,
looks for the upstream artifact first, and when that is missing it asks
for the input or derives it from the code instead of stopping. Each skill
carries its own copy of every template it fills, so it works in a
repository that was never scaffolded. Other skills are named only as the
fuller path, never as prerequisites. `command` means you type it;
`auto` means Claude may load it when the request matches.

<!-- skills-table:start -->
| Skill | What it does | Use when | Invocation |
| --- | --- | --- | --- |
| `ab-experiment` | 'Designs and analyses an A/B test on a feature flag: hypothesis, primary and guardrail metrics, sample size, stopping rule, decision | asked to "A/B test this", "run an experiment" or "sample size".' | auto |
| `accessibility` | 'Audits and fixes accessibility to WCAG 2.2 AA on web and mobile, findings at file:line, axe checks in Playwright | asked about "accessibility", "a11y", "WCAG", "screen reader" or "keyboard navigation".' | auto |
| `adr` | 'Records a decision already made as a numbered ADR (docs/adr/ or the repo''s own folder): context, options, decision, consequences | asked to "write an ADR", "record this decision" or "document why we chose".' | auto |
| `analytics-events` | 'Designs the analytics event sheet, wires the analytics SDK behind one typed module and audits code against the sheet | asked to "track this feature", "add an event", "set up analytics" or "audit tracking".' | auto |
| `android` | 'Conventions for native Android: Kotlin, Jetpack Compose, Material 3, Hilt, coroutines, Room, Retrofit, Gradle, ktlint, detekt | writing, reviewing or scaffolding "Android", "Kotlin" or "Compose" code.' | auto |
| `api-versioning` | 'Versions and retires API endpoints: Deprecation and Sunset headers, consumer inventory, breaking-change diff, contract tests, log-gated removal | asked to "deprecate an endpoint", "version the API" or "sunset".' | auto |
| `app-store-release` | 'Prepares an App Store or Google Play submission: build numbers, listing, screenshots, privacy forms, phased rollout, rejection fixes | asked to "submit to the App Store", "TestFlight" or "app rejected".' | auto |
| `architecture-diagram` | 'Draws the architecture from the code as it is: C4 and sequence diagrams in mermaid, SVG and PNG, every box sourced | asked to "draw the architecture", "C4 diagram" or "sequence diagram".' | auto |
| `auth` | 'Builds authentication and authorisation: sessions or tokens, passkeys, OAuth, RBAC, tenant isolation, IDOR checks, a permission matrix as tests | asked to "add login", "roles and permissions" or "who can access".' | auto |
| `autopilot` | 'Runs unattended from one requirement statement to a prepared merge request, taking each decision as Proposed for review; never pushes | asked to "autopilot this", "run it end to end" or "build this unattended".' | auto |
| `background-jobs` | 'Builds background jobs that survive failure: queue, cron or outbox, idempotency keys, backoff retries, dead letters, graceful shutdown | asked for a "background job", "queue", "cron job", "worker" or "outbox".' | auto |
| `backlog` | 'Turns PRD requirements into a backlog of epics and Given-When-Then user stories with a coverage matrix, combining statements | asked to "write the user stories", "build the backlog" or "break down the PRD".' | auto |
| `branch-review` | 'Code review of a branch, MR, patch or path with stack checklists, every Critical and High finding independently verified, and merge verdict | asked to "review this", "review the MR" or "look over my changes".' | auto |
| `ci-pipeline` | 'Generates or refreshes the CI pipeline for the stack (GitLab CI, GitHub Actions or both), every job a make target, deploys manual | asked to "add CI", "set up the pipeline", "fix the pipeline" or "add a CI job".' | auto |
| `client-deliverables` | 'Builds the client documentation pack: numbered folders, each document as Markdown, CSV and versioned Word, and a delivery checklist | asked to "build the client pack" or "export the docs to Word".' | auto |
| `client-handover` | 'Writes the client handover pack at the end of an engagement: environments, access list, deploy, runbooks, debt, licences, sign-off | asked to "prepare the handover" or "hand this over to the client".' | auto |
| `cloud-cost` | 'Reviews the cloud bill read-only: spend by service and environment, top ten lines, cost per request, proposed cuts | asked about the "cloud bill", "cost review", "FinOps" or "why is the bill so high".' | auto |
| `company-attribution` | 'Sets who owns a repository: organisation profile, LICENSE and NOTICE, CODEOWNERS, SECURITY.md, package metadata | asked to "add a licence", "attribute this repo to" or "who owns this code".' | auto |
| `computer-vision` | 'Builds computer vision features (VLM, classifier, detector, anomaly, document extraction) with leak-free splits and a cost-set threshold | asked to "classify images", "detect defects" or "extract from scans".' | auto |
| `data-model` | 'Designs the data model from the stories: data-model doc, runnable schema.sql, data dictionary and ERD, a reason per column | asked to "design the data model", "what tables do we need" or "draw the ER diagram".' | auto |
| `data-pipeline` | 'Conventions for data pipelines: dbt-core models with tests, Airflow 3 DAGs, sqlfluff, ruff, pytest, uv, partitioned backfills | writing, reviewing or scaffolding "dbt models", "an Airflow DAG" or "a backfill".' | auto |
| `database` | 'Conventions for PostgreSQL, ClickHouse and MongoDB: store choice, schema, indexes, query review, lock-safe migrations | "designing a schema", "choosing an index", "reviewing a query" or "which database".' | auto |
| `db-migration` | 'Writes a database migration with a tested down step and lock-safety notes (goose, Alembic, Prisma, Knex, Room, GRDB, ClickHouse, Mongo) | asked to "add a migration", "add a column" or "change the schema".' | auto |
| `definition-of-done` | 'Checks the current branch against the Definition of Done with evidence per item: gate, tests, docs, scope, commits, a smoke run of the app | asked "am I done", "is this ready to merge" or "definition of done".' | auto |
| `dependency-audit` | 'Audits dependencies for vulnerabilities and outdated versions, applies approved patch and minor upgrades with tests, keeps Renovate current | asked to "audit dependencies", "update the packages" or "bump deps".' | auto |
| `deployment-architecture` | 'Documents how the system is deployed, with a diagram: environments, topology, scaling, backups, rollback, DR, each claim sourced | asked "how is this deployed", "what runs where" or "document the deployment".' | auto |
| `design-critique` | 'Scores a UI design (design gallery, running app or HTML prototype) at three widths, both themes, eleven categories, with an AI-slop check | asked to "critique this design", "review the prototype" or "score this".' | auto |
| `design-directions` | 'Produces three genuinely different visual design directions over the real screens, scores them and records the choice | asked for "design directions", "three design options" or "which look should we go with".' | auto |
| `design-system` | 'Turns a design direction into a design system: oklch tokens, per-stack themes, a component contract, an every-state page and a lint | asked to "set up the design system", "make design tokens" or "lint colours".' | auto |
| `docs-drift` | 'Finds docs that no longer match the code (broken links and paths, gone make targets, unused env vars, stale pages) and fixes the stale side | asked "are the docs up to date", "check the README" or "docs drift".' | auto |
| `doctor` | 'Checks this machine and repository are set up for this plugin: skill packs, hooks, CLAUDE.md import, rules, hooksPath, with a fix per miss | asked to "check my setup", "is it installed" or a hook is missing.' | auto |
| `estimate` | 'Estimates the backlog: story points and task hours with assumptions, dependencies, a phase plan and a confidence range | asked "how long will this take", "estimate the backlog" or "size the stories".' | auto |
| `explain-codebase` | 'Explains a repository or subsystem read-only, path:line for every claim: entry points, module map, one request traced, key files | asked to "explain this repo", "how does this work" or "where is X handled".' | auto |
| `feature-flags` | 'Adds, uses or removes a feature flag: default off, owner, removal date, one typed flags module, kill switch, tests for both states | asked to "put this behind a flag", "add a feature flag" or "remove the flag".' | auto |
| `feature-patterns` | 'Plans one common feature mechanism (uploads, search, realtime, caching, rate limits, payments, notifications, multitenancy) with tests | asked to "add file uploads", "add search" or "rate limiting".' | auto |
| `flutter` | 'Conventions for Flutter: Dart 3, Riverpod, go_router, dio, freezed, ARB localisation, flavours, flutter_test, integration_test, fastlane | writing, reviewing or scaffolding "Flutter", "Dart" or "Riverpod" code.' | auto |
| `gate-audit` | 'Audits every gate (CI jobs, git hooks, make check, hook scripts) for passing on empty input, printing no count or asserting a constant | asked to "audit the gates", "is this check real" or "check the CI checks".' | auto |
| `genai-design` | 'Designs a GenAI solution before code: success metric, approach with the cheaper option rejected, model tier, cost, latency, risks, eval plan | asked "how should we build this with an LLM" or "RAG or agent".' | auto |
| `git-hooks` | 'Installs or repairs the committed git hooks (commit-msg, pre-commit, pre-push), sets core.hooksPath and dry-runs each | asked to "install the git hooks", "set up hooks" or "why was my commit rejected".' | auto |
| `go` | 'Conventions for Go services: net/http mux, pgx, sqlc, goose, slog, golangci-lint, table-driven and httptest tests | writing, reviewing or scaffolding "Go" code, "a Go handler" or "sqlc queries".' | auto |
| `harness-setup` | 'Sets up a repository for another coding agent (Cursor, Codex, Gemini CLI, Copilot, OpenCode, Windsurf, Cline, Zed, Kiro): rules, hooks, skills | asked to "set up Cursor" or "use this with Codex".' | auto |
| `health-checks` | 'Builds /healthz and /readyz endpoints with per-dependency checks, a scheduled synthetic journey suite, uptime probes and alerts | asked to "add health checks", "readiness endpoint" or "uptime monitoring".' | auto |
| `high-level-design` | 'Writes a High Level Design (HLD): goals and non-goals agreed first, then architecture, data, interfaces, failure modes, scaling, rollout | asked for an "HLD", "system design", "high level design" or "design doc".' | auto |
| `i18n` | 'Internationalises the app: string catalogs per platform, ICU plurals, locale formatting, fallbacks, an RTL check, a missing-key count | asked to "add a language", "translate the app", "add i18n" or "support RTL".' | auto |
| `incident` | 'Runs a live incident as scribe: severity, UTC timeline, roles, runbook steps for a person, comms, postmortem hand-off; never remediates | "we have an outage", "declare an incident" or "the alert is firing".' | auto |
| `infra` | 'Conventions for infrastructure code: Terraform modules and remote state, per-environment directories, tflint, Trivy, kustomize, plan-only CI | writing or reviewing "Terraform", "k8s manifests" or "infra".' | auto |
| `ios` | 'Conventions for native iOS: Swift 6, SwiftUI, Observation, Swift Concurrency, SwiftPM, XcodeGen, SwiftData, Swift Testing, Fastlane | writing, reviewing or scaffolding "Swift", "SwiftUI" or "iOS" code.' | auto |
| `license-compliance` | 'Checks open-source licences: a CycloneDX SBOM, a licence inventory against an allow and deny policy, third-party notices | asked for an "SBOM", "licence check", "third-party notices" or "which licences".' | auto |
| `llm-agent` | 'Builds an LLM agent on the Anthropic SDK: tiered tool registry, bounded loop, memory, call logging, guardrails, trajectory evals, kill switch | asked to "build an agent", "give the model tools" or "multi-agent".' | auto |
| `llm-eval` | 'Evaluates an LLM feature: a success metric, a human-labelled golden set, code graders then an LLM judge, a CI regression gate | asked to "evaluate the model", "build an eval set" or "is the new prompt better".' | auto |
| `llm-fine-tuning` | 'Fine-tunes an open model when prompting and RAG fall short: eval-backed decision, dataset, LoRA, DPO or distillation, vLLM serving | asked to "fine-tune a model", "train on our data" or "distil a smaller model".' | auto |
| `llm-gateway` | 'Puts every LLM call behind one gateway module: routing by model tier, retries, timeouts, rate limits, caching, cost tracking, fallbacks | asked to "add an LLM call", "track LLM cost" or "find every model call".' | auto |
| `llm-guardrails` | 'Adds guardrails to an LLM feature: prompt injection and PII checks before the model, a tool-call permission gate, output checks, adversarial tests | asked for "guardrails", "prompt injection" or "PII in prompts".' | auto |
| `load-test` | 'Writes k6 load tests from the SLOs with failing thresholds (smoke, load, stress, soak) and a manual CI job; refuses production | asked to "load test", "performance test the API", "soak test" or "hold p95".' | auto |
| `logging` | 'Adds structured logging: one logger, request id bound at the edge, shared field names, redaction, sampling, HTTP request logs | asked to "add logging", "improve the logs", "log the requests" or "fix the logs".' | auto |
| `low-level-design` | 'Writes a Low Level Design (LLD) refining one HLD component into modules, types, error paths, indexed queries, tests and MR-sized work | asked for an "LLD", "low level design" or "detailed design".' | auto |
| `mcp-server` | 'Builds an MCP server in Python or TypeScript: schema-checked tools, both transports, auth, a test per tool, Claude Code registration | asked to "build an MCP server" or "expose this as MCP tools".' | auto |
| `merge-request` | 'Prepares the merge request for the current branch: gate run, commit audit, diff summary, MR description, ticket link, push command; never pushes | asked to "prepare the MR", "write the PR description".' | auto |
| `motion-design` | 'Writes the motion spec and tokens and builds a requested animation (hero, page transition, interaction) with a reduced-motion path | asked to "add animation", "animate this" or "respect reduced motion".' | auto |
| `new-repo` | 'Creates a new repository for one stack with Makefile, CI, git hooks, CLAUDE.md, AGENTS.md, rules, MR templates and docs in place | asked to "create a repo", "scaffold a service" or "start a new project".' | auto |
| `new-skill` | 'Creates a new skill for this plugin in its git checkout with the house sections and lints, then evals it against a baseline | asked to "add a skill", "make this a skill" or "turn this checklist into a skill".' | auto |
| `nextjs` | 'Conventions for Next.js: Next 16 App Router, React 19, server components, server actions with Zod, Tailwind v4, shadcn/ui, Playwright | writing, reviewing or scaffolding "Next.js" or "App Router" code.' | auto |
| `node` | 'Conventions for Node services: Node 24, TypeScript, Fastify 5, Zod 4, Drizzle ORM, pino, OpenTelemetry, vitest, pnpm | writing, reviewing or scaffolding "Fastify", "Drizzle" or "a Node API" code.' | auto |
| `observability` | 'Wires OpenTelemetry traces and metrics, trace ids in logs, a local Grafana stack, RED dashboards, SLOs and burn-rate alerts | asked to "add observability", "set up tracing", "add dashboards" or "define SLOs".' | auto |
| `on-call` | 'Sets up on-call: rotation, escalation, alert routing by severity, error budget policy, handover notes, a runbook for every paging alert | asked about "on-call", "who gets paged", "escalation" or "error budget".' | auto |
| `onboard-repo` | 'Brings an existing repository onto the team conventions (Makefile, hooks, CLAUDE.md, rules) without overwriting; conflicts land beside the file | asked to "onboard this repo" or "adopt the standard".' | auto |
| `openapi-spec` | 'Designs or audits the OpenAPI 3.1 contract in api/openapi.yaml, generates readable API docs and counts spec and route drift | asked to "write the OpenAPI spec", "design the API contract" or "check the spec".' | auto |
| `performance` | 'Profiles and fixes slowness with the stack''s profiler (pprof, py-spy, clinic, Lighthouse, Instruments), with before and after numbers | told "this is slow", "profile this", "optimise" or "p95 is high".' | auto |
| `postmortem` | 'Writes a blameless postmortem after an incident: impact in numbers, UTC timeline, root cause chain, owned follow-ups, lessons | asked for a "postmortem", "RCA", "incident report" or "write up the outage".' | auto |
| `prd` | 'Normalises any brief, notes or ticket into a PRD of numbered testable REQ statements, objectives, personas and open questions; no stories | asked to "write the PRD" or "turn this brief into requirements".' | auto |
| `privacy-review` | 'Reviews personal data handling: a data map with purpose, basis and retention, deletion wired to it, data subject requests, a DPIA | asked about "GDPR", "DPDP", "personal data", "retention" or "delete my account".' | auto |
| `prompt-registry` | 'Keeps prompts in a versioned registry (prompts/<name>/vN.md) loaded by one module, with typed variables, fixture tests and scores | asked to "write the system prompt", "improve this prompt" or "version prompts".' | auto |
| `prose-lint` | 'Lints prose people read (docs, MR text, commits, UI copy) for em dashes, AI filler and self-praise, rewriting whole sentences | asked to "check the prose", "lint the README" or "does this sound AI-written".' | auto |
| `python` | 'Conventions for Python services: Python 3.14, FastAPI, Pydantic v2, SQLAlchemy 2 async, Alembic, structlog, uv, ruff, pytest | writing, reviewing or scaffolding "FastAPI", "Pydantic" or "Python service" code.' | auto |
| `rag` | 'Builds retrieval-augmented generation (RAG) on pgvector: ingestion, chunking, embeddings, a retriever with citations, retrieval metrics | asked to "add RAG", "chat with our documents" or "chunk and embed".' | auto |
| `react` | 'Conventions for React web apps: React 19, TypeScript, Vite, TanStack Query and Router, Zustand, Zod, shadcn/ui, Tailwind v4, vitest | writing, reviewing or scaffolding "React", "TSX", "shadcn" or "Tailwind" code.' | auto |
| `react-native` | 'Conventions for React Native: Expo SDK 57, expo-router, TypeScript, TanStack Query, Zustand, Zod, NativeWind, EAS, Maestro | writing, reviewing or scaffolding "React Native", "Expo" or "NativeWind" code.' | auto |
| `refactor` | 'Refactors without changing behaviour: tests green first, one mechanical change per commit, checks between, a diff size ceiling | asked to "refactor", "clean this up", "extract" or "rename across the codebase".' | auto |
| `release` | 'Prepares a release: version from commits or from the API diff for packages, CHANGELOG section, version bump, printed tag commands | asked to "cut a release", "bump the version" or "publish the package".' | auto |
| `resilience-testing` | 'Tests the failure modes the design claims: fault injection plan, backup restore drills, DR tests with measured RTO and RPO | asked about "chaos testing", "restore drill", "DR test" or "what if the database dies".' | auto |
| `runbook` | 'Writes or updates the runbook for one alert: meaning, impact, diagnosis commands, remediation, rollback, escalation | asked to "write a runbook", "document this alert" or "what do we do when X fires".' | auto |
| `screen-design` | 'Designs every screen in every state, desktop and phone: React and shadcn screens in the app''s design gallery, or HTML mockups | asked to "design the screens", "hi-fi mockups" or "show every state".' | auto |
| `secrets` | 'Handles secrets without seeing values: inventory, rotation, leak response (revoke, rotate, scrub, audit), gitleaks, .env.example parity | "a key was committed", "rotate the secret" or "secret leaked".' | auto |
| `session-handoff` | 'Saves session state for the next session on this branch: next steps, done, blockers, questions, files, gate, and a progress note | asked to "save state", "write a handoff", "pause here" or before /clear.' | auto |
| `speech` | 'Builds speech features: transcription, diarisation, text-to-speech or a real-time voice agent with barge-in, measured by WER and latency | asked to "transcribe calls", "build a voice agent" or "speech to text".' | auto |
| `spike` | 'Runs a timeboxed spike: a yes, no or number question, a timebox and stop condition, throwaway code never merged, a written recommendation | asked to "spike this", "investigate whether" or "prototype to find out".' | auto |
| `start-task` | 'Starts work on a ticket: creates the branch from the right base with the task id, writes state and progress notes, restates the criteria | asked to "start TASK-142", "pick up this ticket" or "create a branch".' | auto |
| `tabular-ml` | 'Builds classical ML on tabular or event data (churn, scoring, forecasts, anomalies) with leak-proof splits, a baseline, calibration, drift checks | asked to "predict churn", "forecast demand" or "train a model".' | auto |
| `task-report` | 'Reports a finished task under four headings: Changed, Verified, Not done, Noticed | asked to "write up what you did", "report back", "summarise the work", "give me the status" or at the end of any task.' | auto |
| `tech-debt` | 'Keeps the tech debt register in docs/DEBT.md, seeded from TODOs, suppressed lints and skipped tests, ranked by cost of carrying it | asked about "tech debt", "what should we clean up next" or "the debt register".' | auto |
| `tech-decision` | 'Chooses between technology options: lays out options, recommends with reasons, lets the user decide, records each choice as an ADR | asked "Kafka or RabbitMQ", "which cloud" or "what stack should we use".' | auto |
| `test-automation` | 'Sets up or extends the automated test suite (Playwright, Maestro, Espresso, pytest, Go httptest), one test per planned test case by TC id | asked to "automate the test cases", "set up Playwright" or "e2e tests".' | auto |
| `test-cases` | 'Writes test cases from acceptance criteria: risk per story, scenarios, TC-numbered cases with steps and a test plan; no test code | asked to "write the test cases", "build the test plan" or "cover the criteria".' | auto |
| `test-heal` | 'Fixes failing or flaky tests: classifies each failure with evidence, heals locator, timing and data drift, leaves regressions red, quarantines flakes | asked to "fix the flaky tests" or "heal the tests".' | auto |
| `test-run` | 'Runs every test suite present into one report: failures at file:line, slowest, flaky, coverage; a suite that did not run never passes | asked to "run the tests", "what is failing" or "run TC-0231".' | auto |
| `themes` | 'Adds and manages themes on the design system (dark, high contrast, brand, tenant, seasonal) with contrast checks and a preview | asked to "add dark mode", "add a high contrast theme" or "theme for a tenant".' | auto |
| `threat-model` | 'Writes a STRIDE threat model before code: assets, trust boundaries, entry points, threats rated, mitigations mapped to stories | asked to "threat model this", "STRIDE analysis" or "what could an attacker do".' | auto |
| `traceability` | 'Builds the traceability matrix from requirements through stories, test cases, tests, commits and tickets, counting every gap; read-only | asked "is everything traced", "traceability matrix" or "untested".' | auto |
| `tracker-sync` | 'Creates and updates tickets in the configured tracker (Jira, GitLab, GitHub or none): create, sync the backlog, move status, link MRs | asked to "create the tickets", "sync to Jira" or "move TASK-142".' | auto |
| `upgrade-tools` | 'Upgrades every installed Claude Code plugin and skill pack on this machine (plugins, gstack, skills CLI, GSD), versions before and after | asked to "update the plugins", "upgrade the skills" or "update all".' | auto |
| `ux-flows` | 'Maps UX flows: screen inventory tied to stories, every state with copy, storyboard, flow diagrams and a zero dead-end check | asked to "map the user flows", "what screens do we need" or "user journey".' | auto |
| `vapt-report` | 'Writes the VAPT security report for a release from scanner findings, linked to the threat model, with a ship or block decision | asked for a "VAPT report", "security sign-off" or "pentest report".' | auto |
| `verify-deploy` | 'Checks one environment after the engineer deploys: readiness, health, version, smoke pages, synthetic suite; read-only, never rolls back | asked to "verify the deploy", "check qa after deploying".' | auto |
| `webhooks` | 'Builds webhooks both ways: inbound with signature checks, replay window and idempotent handlers; outbound with retries, dead letters and a delivery log | asked to "add a webhook" or "verify signatures".' | auto |
| `workflow` | 'Says where the work stands (repository, branch, diff) and which skill or step comes next | asked "what should I do next", "which skill do I use", "how do we work here" or "what is in flight".' | auto |
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
  speaking the REST tracker protocol, or none) through `bin/brg-tracker`,
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
  when a dark theme did not apply. It is main while only prototypes exist; once the app runs in
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
  schemas, auth, tests and the harness registration; main for "tools for
  models", with `build-mcp-server` (mcp-server-dev) as the alternate.
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
the guidelines, review checklist, rules file and scaffold templates.

- **react**, **go**, **python**, **react-native**,
  **android**, **ios**, **infra**, **database**; the
  Node, Next.js, Flutter and data lanes are being added and appear in the
  table above once their directories exist.
