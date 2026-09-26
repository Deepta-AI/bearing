#!/usr/bin/env python3
"""Generate the documents that derive from the skills in this repository:

  site/src/data/handbook.json   everything the handbook site renders
  docs/WORKFLOW.md              the stage tables between the markers

Every table comes from one source: the skill frontmatter (name,
description, invocation), CATEGORY and STAGES below, plus one reviewed
file: docs/flows.json (the four task flows). Fails when zero skills are
found, when a skill has no category, when a row names more than one skill,
or when a row or a flow names a skill that is neither a Bearing skill nor
listed in docs/known-skills.txt.

    gen-guide.py                        write every document
    gen-guide.py --write-known-skills   rewrite docs/known-skills.txt from
                                        the skills installed on this
                                        machine, then continue
    gen-guide.py --check-names          the default; kept as a flag so a
                                        caller can name the intent"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "bin"))
import kit_paths  # noqa: E402

BEARING = kit_paths.BEARING
SKILL_DIRS = kit_paths.skill_dirs()
VERSION = (ROOT / "VERSION").read_text().strip()
KNOWN = ROOT / "docs" / "known-skills.txt"
WALKTHROUGH = ROOT / "docs" / "examples" / "walkthrough.md"

# Lanes that may be absent in a trimmed fork. A CATEGORY entry without a
# directory is skipped with a note, never a failure.
FUTURE = {"node", "nextjs", "flutter", "data-pipeline"}

CATEGORY = {
    "product": [
        "prd",
        "backlog",
        "estimate",
        "tracker-sync",
        "spike",
        "ab-experiment",
    ],
    "architecture": [
        "tech-decision",
        "adr",
        "explain-codebase",
        "architecture-diagram",
        "high-level-design",
        "low-level-design",
        "openapi-spec",
        "api-versioning",
        "auth",
        "background-jobs",
        "webhooks",
        "feature-patterns",
        "data-model",
        "deployment-architecture",
        "threat-model",
    ],
    "design": [
        "ux-flows",
        "design-directions",
        "design-system",
        "screen-design",
        "themes",
        "motion-design",
        "design-critique",
    ],
    "repository": [
        "new-repo",
        "onboard-repo",
        "company-attribution",
        "ci-pipeline",
        "git-hooks",
    ],
    "platform": [
        "observability",
        "logging",
        "health-checks",
        "analytics-events",
        "i18n",
        "feature-flags",
        "dependency-audit",
        "secrets",
        "license-compliance",
        "privacy-review",
    ],
    "task flow": [
        "start-task",
        "session-handoff",
        "task-report",
        "definition-of-done",
        "merge-request",
        "release",
        "app-store-release",
        "refactor",
        "tech-debt",
    ],
    "quality": [
        "test-cases",
        "test-automation",
        "test-run",
        "test-heal",
        "load-test",
        "performance",
        "resilience-testing",
        "accessibility",
        "branch-review",
        "vapt-report",
        "gate-audit",
        "prose-lint",
        "traceability",
        "db-migration",
        "docs-drift",
    ],
    "operate": [
        "verify-deploy",
        "runbook",
        "incident",
        "postmortem",
        "on-call",
        "cloud-cost",
        "client-handover",
        "client-deliverables",
    ],
    "genai": [
        "genai-design",
        "prompt-registry",
        "llm-agent",
        "rag",
        "llm-eval",
        "llm-fine-tuning",
        "mcp-server",
        "llm-guardrails",
        "llm-gateway",
        "speech",
        "computer-vision",
        "tabular-ml",
    ],
    "stacks": [
        "react",
        "nextjs",
        "node",
        "go",
        "python",
        "data-pipeline",
        "react-native",
        "flutter",
        "android",
        "ios",
        "infra",
        "database",
    ],
    "meta": [
        "workflow",
        "autopilot",
        "doctor",
        "upgrade-tools",
        "new-skill",
        "harness-setup",
    ],
}
CAT_OF = {s: c for c, names in CATEGORY.items() for s in names}

# The Bearing skills: every directory under a Bearing plugin's skills/ that
# holds a SKILL.md (plugins/bearing, plugins/bearing-backend, plugins/bearing-apps).
# Membership in this set, not a name prefix, is what makes a name a Bearing skill.
existing = {p.name for p in SKILL_DIRS}
absent = [s for s in CAT_OF if s not in existing]
for s in absent:
    print(f"note: {s} is in CATEGORY but has no SKILL.md in any plugin yet; skipped")

skills = []
for skill_d in SKILL_DIRS:
    skill = skill_d / "SKILL.md"
    text = skill.read_text(encoding="utf-8")
    m = re.search(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        sys.exit(f"no frontmatter: {skill}")
    fm = m.group(1)
    name = re.search(r"^name: (.+)$", fm, re.M).group(1).strip()
    desc = re.search(r"^description: (.+)$", fm, re.M).group(1).strip()
    # One-line YAML scalars: 'single' ('' is a quote) or "double" quoted.
    if len(desc) >= 2 and desc[0] == desc[-1] == "'":
        desc = desc[1:-1].replace("''", "'")
    elif len(desc) >= 2 and desc[0] == desc[-1] == '"':
        desc = desc[1:-1].replace('\\"', '"')
    cmd = bool(re.search(r"^disable-model-invocation: true", fm, re.M))
    arg = re.search(r'^argument-hint: "?(.+?)"?$', fm, re.M)
    what, _, when = desc.partition(" Use when ")
    phrases = re.findall(r'"([^"]+)"', when)
    skills.append(
        {
            "name": name,
            "plugin": kit_paths.plugin_of(skill_d),
            "category": CAT_OF.get(name, "other"),
            "what": what.strip().rstrip("."),
            "when": when.strip().rstrip("."),
            "phrases": phrases,
            "invocation": "command" if cmd else "auto",
            "args": arg.group(1).strip() if arg else "",
        }
    )
if not skills:
    sys.exit("0 skills found")
missing = [s["name"] for s in skills if s["category"] == "other"]
if missing:
    sys.exit(f"skills without a category: {missing}")
# A skill may carry more than one stack: templates/ and templates-<variant>/
# (go has go-api and go-cli).
STACKS = sorted(
    {p.parent.parent.name for d in SKILL_DIRS for p in d.glob("templates*/stack.json")}
)


# One main skill per row. Columns: stage, skill, pack, output.
STAGES = [
    (
        "Discover",
        [
            (
                "Pressure-test the idea",
                "/office-hours",
                "gstack",
                "a go or no-go with reasons",
            ),
            (
                "Timeboxed investigation",
                "spike",
                "bearing",
                "docs/spikes/<date>-<name>.md: the question, the timebox, an answer, a recommendation",
            ),
            (
                "Understand a codebase",
                "explain-codebase",
                "bearing",
                "entry points, module graph, one request's flow, the ten files that matter, every claim at path:line",
            ),
            (
                "Normalise the PRD",
                "prd",
                "bearing",
                "docs/product/PRD.md with REQ-nnn statements",
            ),
            (
                "Backlog from the PRD",
                "backlog",
                "bearing",
                "epics, US- stories with AC-, coverage matrix, user flows",
            ),
        ],
    ),
    (
        "Plan",
        [
            (
                "Size and phase",
                "estimate",
                "bearing",
                "estimate with assumptions and a phase plan",
            ),
            (
                "Tickets in the tracker (optional)",
                "tracker-sync",
                "bearing",
                "tickets linked to stories in Jira, GitLab, GitHub or any REST tracker; with BEARING_TRACKER=none the step is skipped with a note",
            ),
            (
                "Debt register",
                "tech-debt",
                "bearing",
                "docs/DEBT.md: interest, principal, trigger and owner per row, seeded from markers, suppressions and skipped tests",
            ),
            (
                "Plan review",
                "/plan-eng-review",
                "gstack",
                "reviewed plan",
            ),
        ],
    ),
    (
        "Choose",
        [
            (
                "Technology choices",
                "tech-decision",
                "bearing",
                "options with a recommendation; you decide; ADR per choice",
            ),
            (
                "Boundary decision",
                "adr",
                "bearing",
                "docs/adr/ADR-nnnn",
            ),
        ],
    ),
    (
        "Architecture",
        [
            (
                "Architecture diagrams",
                "architecture-diagram",
                "bearing",
                "C4 and sequence diagrams",
            ),
            (
                "High level design",
                "high-level-design",
                "bearing",
                "docs/design/<x>-hld.md",
            ),
            (
                "Low level design",
                "low-level-design",
                "bearing",
                "docs/design/<x>-lld.md",
            ),
            (
                "API contract",
                "openapi-spec",
                "bearing",
                "api/openapi.yaml and a drift report",
            ),
            (
                "API versioning and retirement",
                "api-versioning",
                "bearing",
                "versioning choice, Deprecation and Sunset headers, consumer inventory, a removal gate counted from logs",
            ),
            (
                "Authentication and authorisation",
                "auth",
                "bearing",
                "session or token choice with reasons, permission matrix, IDOR checks, tenant isolation, token rotation",
            ),
            (
                "Background work",
                "background-jobs",
                "bearing",
                "queue, cron or outbox with idempotency keys, retries, dead letters, graceful shutdown",
            ),
            (
                "Webhooks",
                "webhooks",
                "bearing",
                "signed inbound handlers with a replay window; outbound catalogue with retries and dead letters",
            ),
            (
                "Known problem, known pattern",
                "feature-patterns",
                "bearing",
                "uploads, search, realtime, cache, rate limit, payments, notifications, multitenancy: decision, data model, failure modes, tests",
            ),
            (
                "Data model",
                "data-model",
                "bearing",
                "ERD, schema per store, migration plan",
            ),
            (
                "Deployment architecture",
                "deployment-architecture",
                "bearing",
                "environments, topology, rollback, DR",
            ),
            (
                "Threat model",
                "threat-model",
                "bearing",
                "STRIDE table with mitigations",
            ),
        ],
    ),
    (
        "Design the product",
        [
            (
                "UX flows from the spec",
                "ux-flows",
                "bearing",
                "screen inventory, state tables, storyboard, flow diagrams, zero dead ends",
            ),
            (
                "Design direction",
                "/design-consultation",
                "gstack",
                "DESIGN.md with aesthetic, type, colour, spacing, motion",
            ),
            (
                "Three variants to choose from",
                "design-directions",
                "bearing",
                "three distinct HTML variants, comparison board, approved.json",
            ),
            (
                "Design system and tokens",
                "design-system",
                "bearing",
                "tokens.json, per-stack bindings, component contract, design lint",
            ),
            (
                "Screen designs",
                "screen-design",
                "bearing",
                "one HTML prototype per screen with every state, redlines",
            ),
            (
                "Theming",
                "themes",
                "bearing",
                "themes as token overrides, contrast lint, preview page",
            ),
            (
                "Motion and animation",
                "motion-design",
                "bearing",
                "motion spec, hero and banner moments, reduced-motion paths",
            ),
            (
                "Design review and iteration",
                "design-critique",
                "bearing",
                "ten scored categories with evidence on prototypes or a URL, an AI-slop detector, approved fixes, a re-score; used while only prototypes exist; once the app runs in a browser, the workflow calls gstack /design-review",
            ),
            (
                "Copy and clarity",
                "clarify",
                "ui-craft",
                "UX copy reviewed: buttons, errors, empty states, form hints",
            ),
        ],
    ),
    (
        "GenAI features",
        [
            (
                "Problem statement to approach",
                "genai-design",
                "bearing",
                "solution doc, ADR stub, cost and risk",
            ),
            (
                "Prompts",
                "prompt-registry",
                "bearing",
                "versioned registry with tests and eval scores",
            ),
            (
                "Retrieval",
                "rag",
                "bearing",
                "ingestion, pgvector schema, retriever with citations",
            ),
            (
                "Agents",
                "llm-agent",
                "bearing",
                "tool registry, bounded loop, kill switch",
            ),
            (
                "Tools for models",
                "mcp-server",
                "bearing",
                "MCP server with schema-checked tools, both transports, auth, a test per tool, the harness registration",
            ),
            (
                "Safety",
                "llm-guardrails",
                "bearing",
                "policy file, input, tool and output checks",
            ),
            (
                "Every model call",
                "llm-gateway",
                "bearing",
                "routing, retries, caching, cost, tracing",
            ),
            (
                "Is it good enough",
                "llm-eval",
                "bearing",
                "golden set, graders, CI regression gate",
            ),
            (
                "Prompting is not enough",
                "llm-fine-tuning",
                "bearing",
                "data prep, recipe, GPU check, smoke run, vLLM serving, model card",
            ),
            (
                "Speech and voice",
                "speech",
                "bearing",
                "WER per language, latency per stage, barge-in, audio privacy",
            ),
            (
                "Vision",
                "computer-vision",
                "bearing",
                "group-safe splits, AUROC or mAP, threshold from costs, serving latency",
            ),
            (
                "Classical ML and forecasting",
                "tabular-ml",
                "bearing",
                "leakage check, baseline gate, calibration, explanations, drift",
            ),
        ],
    ),
    (
        "Set up the repository",
        [
            (
                "New repository",
                "new-repo",
                "bearing",
                "scaffold with Makefile, CI for the configured git host, hooks, docs, a lockfile",
            ),
            (
                "Existing repository",
                "onboard-repo",
                "bearing",
                "standard files added, conflicts listed beside the file as .bearing-new",
            ),
            (
                "Attribute to a company",
                "company-attribution",
                "bearing",
                ".bearing/company.json, LICENSE, NOTICE, CODEOWNERS",
            ),
            (
                "Pipeline",
                "ci-pipeline",
                "bearing",
                "the pipeline file for the configured git host, every job calling a make target",
            ),
            (
                "Git hooks",
                "git-hooks",
                "bearing",
                ".githooks wired",
            ),
            (
                "Observability stack",
                "observability",
                "bearing",
                "OpenTelemetry, dashboards, alerts, SLOs",
            ),
            (
                "Logging",
                "logging",
                "bearing",
                "structured logs, HTTP logging behind LOG_HTTP",
            ),
            (
                "Health monitoring",
                "health-checks",
                "bearing",
                "healthz, readyz, synthetic probes",
            ),
            (
                "Analytics",
                "analytics-events",
                "bearing",
                "event sheet, tracking plan, SDK wiring",
            ),
            (
                "Internationalisation",
                "i18n",
                "bearing",
                "string catalogs, make i18n-check",
            ),
        ],
    ),
    (
        "Build a task",
        [
            (
                "Start",
                "start-task",
                "bearing",
                "branch feature/TASK-142-<PascalName>, the local state file and the committed docs/progress/TASK-142.md",
            ),
            (
                "Vague request",
                "brainstorming",
                "Superpowers",
                "a spec, triggers on its own",
            ),
            (
                "Plan the change",
                "writing-plans",
                "Superpowers",
                "tasks a fresh session can run",
            ),
            (
                "Multi-session work",
                "gsd-plan-phase",
                "GSD Core",
                "phases with state files; gsd-execute-phase runs them",
            ),
            (
                "Understand before changing",
                "explain-codebase",
                "bearing",
                "the subsystem mapped, every claim at path:line, the files a change would touch",
            ),
            (
                "Test cases first",
                "test-cases",
                "bearing",
                "TC-nnnn cases traced to criteria",
            ),
            (
                "Write code",
                "test-driven-development",
                "Superpowers",
                "tested code; stack skills load on their own",
            ),
            (
                "Restructure without changing behaviour",
                "refactor",
                "bearing",
                "tests green first, one mechanical transform per commit, make check between, a diff ceiling",
            ),
            (
                "Something is slow",
                "performance",
                "bearing",
                "before and after numbers from the stack's profiler, docs/performance/<name>.md",
            ),
            (
                "A secret to add or rotate",
                "secrets",
                "bearing",
                "docs/security/SECRETS.md inventory, rotation per type, leak response, gitleaks pre-commit",
            ),
            (
                "Schema change",
                "db-migration",
                "bearing",
                "migration with a tested Down",
            ),
            (
                "Feature flag",
                "feature-flags",
                "bearing",
                "flag with owner and removal task",
            ),
            (
                "Feature analytics",
                "analytics-events",
                "bearing",
                "events wired and tested",
            ),
            (
                "Broken, no obvious cause",
                "systematic-debugging",
                "Superpowers",
                "root cause, then fix",
            ),
            (
                "Merge conflict",
                "resolving-merge-conflicts",
                "mattpocock",
                "both sides' intent kept and the project's checks green; you start the rebase",
            ),
            (
                "Pause mid-task",
                "session-handoff",
                "bearing",
                ".bearing/state/<branch>.md (local detail) and docs/progress/<ID>.md (the shared summary)",
            ),
        ],
    ),
    (
        "Verify",
        [
            (
                "Automated tests",
                "test-automation",
                "bearing",
                "suite per stack, generated tests by TC id",
            ),
            (
                "Run tests, pass/fail report",
                "test-run",
                "bearing",
                "docs/testing/reports/<date>.md and .json",
            ),
            (
                "Docs still match the code",
                "docs-drift",
                "bearing",
                "a drift report with counts: broken paths, make targets and config names, docs older than their code; code is the truth for what it does, the doc for what was intended",
            ),
            (
                "Self-heal tests",
                "test-heal",
                "bearing",
                "healed tests, quarantine, healing log, regressions kept red",
            ),
            (
                "Load and performance",
                "load-test",
                "bearing",
                "k6 scripts with thresholds",
            ),
            (
                "Resilience",
                "resilience-testing",
                "bearing",
                "fault plan against the HLD failure-mode table, a dated restore drill, a DR test with measured RTO and RPO",
            ),
            (
                "Accessibility",
                "accessibility",
                "bearing",
                "findings fixed or listed",
            ),
            (
                "Privacy review",
                "privacy-review",
                "bearing",
                "data map, deletion wired to it, DSAR paths, a DPIA, a PII lint",
            ),
            (
                "Open-source compliance",
                "license-compliance",
                "bearing",
                "CycloneDX SBOM, licence inventory gated by policy with counts, NOTICE-THIRD-PARTY.md",
            ),
            (
                "Definition of done",
                "definition-of-done",
                "bearing",
                "verdict with evidence",
            ),
            (
                "Code review",
                "branch-review",
                "bearing",
                "gstack /review with the stack checklists, then an independent verifier on every Critical and High",
            ),
            (
                "Security review",
                "/cso",
                "gstack",
                "a verified report under .gstack/security-reports/ (use --diff on a branch)",
            ),
            (
                "Browser QA",
                "/qa",
                "gstack",
                "QA report",
            ),
            (
                "Gates are real",
                "gate-audit",
                "bearing",
                "per-gate table",
            ),
            (
                "Traceability",
                "traceability",
                "bearing",
                "docs/traceability.md, zero gaps",
            ),
            (
                "Report back",
                "task-report",
                "bearing",
                "Changed, Verified, Not done, Noticed",
            ),
        ],
    ),
    (
        "Ship",
        [
            (
                "Merge request or pull request",
                "merge-request",
                "bearing",
                "description in .scratch, push command; the engineer pushes",
            ),
            (
                "Ticket update (optional)",
                "tracker-sync",
                "bearing",
                "ticket moved, MR linked; skipped with a note when BEARING_TRACKER is none",
            ),
            (
                "Release",
                "release",
                "bearing",
                "CHANGELOG, version, tag command",
            ),
            (
                "Publish a package or CLI",
                "release",
                "bearing",
                "with --package: API diff since the last tag, semver from the diff, pack check, provenance, the publish command printed",
            ),
            (
                "App Store or Play submission",
                "app-store-release",
                "bearing",
                "build numbers, listing, tracks, phased rollout with halt rules, every store command printed",
            ),
            (
                "Experiment on a flag",
                "ab-experiment",
                "bearing",
                "hypothesis, primary and guardrail metrics, sample size, exposure events, stopping rules",
            ),
            (
                "Release docs",
                "/document-release",
                "gstack",
                "docs updated",
            ),
            (
                "Security scan before production",
                "claude-security",
                "official",
                "CLAUDE-SECURITY-<ts>/ with verified findings, SARIF and the scanned commit",
            ),
            (
                "VAPT report",
                "vapt-report",
                "bearing",
                "docs/security/VAPT-<version>.md written from the scanner findings, tied to the threat model, with the release decision",
            ),
            (
                "Dependencies",
                "dependency-audit",
                "bearing",
                "audit, upgrade plan, Renovate config",
            ),
        ],
    ),
    (
        "Operate",
        [
            (
                "New alert",
                "runbook",
                "bearing",
                "docs/runbooks/<alert>.md",
            ),
            (
                "Incident",
                "incident",
                "bearing",
                "live incident doc, comms",
            ),
            (
                "After the incident",
                "postmortem",
                "bearing",
                "blameless postmortem, follow-ups",
            ),
            (
                "On-call",
                "on-call",
                "bearing",
                "rotation, escalation, alert routing by severity, error-budget policy, weekly review",
            ),
            (
                "Cloud cost",
                "cloud-cost",
                "bearing",
                "attribution per service and environment, top ten lines, cuts, a monthly cadence",
            ),
            (
                "Verify the deploy",
                "verify-deploy",
                "bearing",
                "docs/releases/verify-<env>-<time>.md from docs/environments.md: readiness, health, the deployed version against the tag, smoke checks, a verdict and the rollback sentence",
            ),
            (
                "Canary after deploy",
                "/canary",
                "gstack",
                "canary report",
            ),
            (
                "Weekly retro",
                "/retro",
                "gstack",
                "retro notes from the week's commits and shipping",
            ),
            (
                "Handover to the client",
                "client-handover",
                "bearing",
                "docs/handover/HANDOVER.md: environments, access inventory without values, deploy, runbooks, debt, licences",
            ),
            (
                "Client documentation pack",
                "client-deliverables",
                "bearing",
                "deliverables/<Project>_ProjectDocumentation/: twelve folders, each artifact as Markdown, CSV and <Project>_<Artifact>_v<N>.docx with cover and history, README of current versions, CHANGELOG, delivery checklist workbook",
            ),
        ],
    ),
    (
        "Keep the workflow healthy",
        [
            (
                "One statement to a prepared MR, unattended",
                "autopilot",
                "bearing",
                "PRD, stories, Proposed decisions and a product profile in one digest, C4 and deployment diagrams, HLD, data model, API contract, LLD, UX flows, design system, screens, test cases, test-first build, test automation, design review, code review, a smoke run, MR description; never pushed",
            ),
            (
                "Not sure what comes next",
                "workflow",
                "bearing",
                "the stage you are in, what is in flight (docs/progress/), the next skill, and whether the work is one agent, bounded tasks or parallel subagents",
            ),
            (
                "Something missing",
                "doctor",
                "bearing",
                "checks with counts and fixes",
            ),
            (
                "Update the packs",
                "upgrade-tools",
                "bearing",
                "versions before and after",
            ),
            (
                "A new repeatable procedure",
                "new-skill",
                "bearing",
                "a Bearing skill on the kit conventions, lints passing, handed to skill-creator for its evals",
            ),
            (
                "Measure a skill",
                "skill-creator",
                "Anthropic",
                "evals/evals.json, with-skill runs against a baseline, a benchmark, a tuned description",
            ),
            (
                "Another coding harness",
                "harness-setup",
                "bearing",
                "rules, pointer files, hook adapters and skills for Cursor, Codex, Gemini CLI, Copilot, OpenCode, Windsurf, Cline, Zed and Kiro",
            ),
        ],
    ),
]

# What each stage is for, one line, for the stage map on the site.
STAGE_WHEN = {
    "Discover": "an idea, a brief or a codebase you do not know yet",
    "Plan": "sizing, tickets, the debt register, the plan review",
    "Choose": "any technology or boundary choice; never made silently",
    "Architecture": "designs, contracts, auth, jobs, webhooks, data, deployment, threats",
    "Design the product": "flows, variants, tokens, screens, themes, motion, copy",
    "GenAI features": "anything that calls, trains or serves a model: language, speech, vision, classical ML",
    "Set up the repository": "a new or adopted repository and its platform concerns",
    "Build a task": "from the branch to the paused or finished change",
    "Verify": "tests, reviews, gates, traceability, the report",
    "Ship": "MR or PR, ticket, release, package, store, experiment, VAPT, dependencies",
    "Operate": "alerts, incidents, on-call, cost, the handover pack",
    "Keep the workflow healthy": "what comes next, doctor, upgrade, a new skill, another harness",
}

# Notes rendered under the stage tables, in the handbook and in WORKFLOW.md.
NOTES = [
    "One skill per row. The Skill column names the one skill the workflow runs for that step; the From column says which plugin or pack provides it. Where that is not Bearing, Bearing calls the installed skill for the step and adds its own gates around it.",
    "analytics-events serves two rows: under Set up the repository it designs the sheet and wires the SDK once; under Build a task it adds one feature's events against that sheet. Same skill, two moments.",
    "explain-codebase serves two rows as well: Discover (a repository you do not know) and Build a task (the subsystem you are about to change).",
    "tracker-sync appears under Plan and under Ship: ticket creation first, then the status and the MR link. With BEARING_TRACKER=none both rows are skipped with a note; rest (any server speaking the REST tracker protocol) is one adapter among none, jira, gitlab and github (docs/TRACKERS.md).",
    "Design review changes skill with time: design-critique while only prototypes exist, gstack /design-review once the app runs in a browser.",
]

for title, rows in STAGES:
    for row in rows:
        if len(row) != 4:
            sys.exit(f"stage row has {len(row)} fields, expected 4: {row}")
        if "," in row[1]:
            sys.exit(f"more than one main skill in row '{row[0]}' ({title}): {row[1]}")
    if title not in STAGE_WHEN:
        sys.exit(f"STAGE_WHEN lacks an entry for stage '{title}'")

# ---------------------------------------------------------------- known skills
BUILTIN = {"security-review", "simplify"}  # harness built-ins, not skill folders


def scan_installed():
    home = pathlib.Path.home()
    found = set()
    user = home / ".claude" / "skills"
    if user.is_dir():
        for d in user.iterdir():
            if d.is_dir():
                found.add(d.name)
    cache = home / ".claude" / "plugins" / "cache"
    for d in cache.glob("*/*/*/skills/*"):
        if not d.is_dir():
            continue
        if (d / "SKILL.md").exists():
            found.add(d.name)
        else:
            for e in d.iterdir():
                if e.is_dir() and (e / "SKILL.md").exists():
                    found.add(e.name)
    for f in cache.glob("*/*/*/commands/*"):
        if f.is_file() and f.suffix == ".md":
            found.add(f.stem)
    for d in (user / "gstack").glob("*/"):
        if (d / "SKILL.md").exists():
            found.add(d.name)
    return sorted(n for n in found if n not in existing)


def check_names():
    """Every skill a stage row names must be a Bearing skill or, for a skill
    the workflow calls from another pack, a name in docs/known-skills.txt."""
    if not KNOWN.exists():
        sys.exit(
            f"{KNOWN.relative_to(ROOT)} missing; run gen-guide.py --write-known-skills on a machine with the packs installed"
        )
    known = {
        l.strip()
        for l in KNOWN.read_text(encoding="utf-8").splitlines()
        if l.strip() and not l.startswith("#")
    }
    if not known:
        sys.exit(f"{KNOWN.relative_to(ROOT)} lists 0 skills")
    checked, unknown, own_bad = 0, [], []
    for title, rows in STAGES:
        for stage, main, src, out in rows:
            checked += 1
            if src == "bearing" or main in existing:
                if main not in existing:
                    own_bad.append(f"{main} ({title}: {stage})")
            else:
                name = main.lstrip("/")
                if name not in known and name not in BUILTIN:
                    unknown.append(f"{main} ({title}: {stage})")
    if checked == 0:
        sys.exit("stage names: 0 names checked")
    if unknown or own_bad:
        for u in unknown:
            print(f"unknown skill name: {u}", file=sys.stderr)
        for u in own_bad:
            print(f"unknown Bearing skill: {u}", file=sys.stderr)
        sys.exit(
            f"stage names: {checked} names checked against {len(known)} known, {len(unknown) + len(own_bad)} unknown"
        )
    print(f"stage names: {checked} names checked against {len(existing)} Bearing and {len(known)} known skills, 0 unknown")


argv = sys.argv[1:]
if "--write-known-skills" in argv:
    found = scan_installed()
    if not found:
        sys.exit("known skills: 0 found on this machine; nothing written")
    KNOWN.write_text(
        "# Skill names installed on the maintainer's machine, one per line, sorted.\n"
        "# Generated by bin/gen-guide.py --write-known-skills; the generator checks\n"
        "# every skill a stage row or a flow step names from another pack.\n"
        + "\n".join(found)
        + "\n",
        encoding="utf-8",
    )
    print(f"known skills: {len(found)} written to {KNOWN.relative_to(ROOT)}")
check_names()


# ------------------------------------------------------------------- helpers
def main_label(main, src):
    if main in existing:
        return f"`{main}`"
    return f"`{main}` ({src})"


# --------------------------------------------------------- generated sections
CONFIG_KEYS = [
    (
        "BEARING_TRACKER",
        "which tracker the ticket steps talk to: none, jira, gitlab, github or rest",
        "none",
    ),
    (
        "BEARING_TRACKER_URL",
        "base url of the tracker (Jira site, GitLab host, GitHub host, REST tracker server)",
        "empty; gitlab.com and github.com for those adapters",
    ),
    (
        "BEARING_TRACKER_PROJECT",
        "where tickets live: Jira project key, group/repo, owner/repo, REST tracker project key",
        "empty",
    ),
    (
        "BEARING_TRACKER_EMAIL",
        "login email for Jira and the REST tracker; ignored by GitLab and GitHub",
        "empty",
    ),
    (
        "BEARING_TRACKER_TOKEN",
        "Jira API token, GitLab token (scope api), GitHub token (scope repo), or a REST tracker bearer token; GitLab and GitHub may leave it empty and rely on glab or gh auth",
        "empty",
    ),
    (
        "BEARING_TRACKER_PASSWORD",
        "REST tracker password, when no token is in BEARING_TRACKER_TOKEN",
        "empty",
    ),
    (
        "BEARING_TRACKER_DONE_STATUS",
        "the status brg-tracker close moves a ticket to",
        "Done",
    ),
    (
        "BEARING_TASK_ID_PREFIX",
        "force the id prefix in branch names and commit subjects (PROJ, GH, GL); empty accepts any [A-Z][A-Z0-9]*-<n> id or NOTASK-<n>",
        "empty",
    ),
    (
        "BEARING_GIT_HOST",
        "which host's CI and change template a repository gets: gitlab, github or both; brg-adopt infers it from the origin remote when empty",
        "both",
    ),
    (
        "BEARING_KIT_REMOTE",
        "git url of the Bearing fork developers install from; written into each repository's settings",
        "the kit checkout's own remote, then file://<kit>",
    ),
    ("BEARING_ORG_ID", "reverse-domain id for mobile bundle ids", "com.example"),
]
ROLES = [
    (
        "Engineer",
        "You hold a task branch most days.",
        [
            ("Build a task", "Start"),
            ("Build a task", "Write code"),
            ("Verify", "Definition of done"),
            ("Verify", "Code review"),
            ("Ship", "Merge request or pull request"),
        ],
    ),
    (
        "Tech lead",
        "You decide, review and release.",
        [
            ("Choose", "Technology choices"),
            ("Plan", "Plan review"),
            ("Architecture", "High level design"),
            ("Architecture", "Threat model"),
            ("Ship", "Release"),
        ],
    ),
    (
        "PM or designer",
        "You shape what gets built.",
        [
            ("Discover", "Pressure-test the idea"),
            ("Discover", "Normalise the PRD"),
            ("Discover", "Backlog from the PRD"),
            ("Design the product", "UX flows from the spec"),
            ("Design the product", "Three variants to choose from"),
        ],
    ),
    (
        "Solo developer",
        "No reviewer but you; the gates stand in.",
        [
            ("Keep the workflow healthy", "Not sure what comes next"),
            ("Build a task", "Start"),
            ("Build a task", "Vague request"),
            ("Verify", "Definition of done"),
            ("Ship", "Release"),
        ],
    ),
]
# Every ROLES row must name a real stage row, or the site links to nothing.
row_index = {(t, r[0]): r for t, rows in STAGES for r in rows}
for role, blurb, refs in ROLES:
    for t, st in refs:
        if (t, st) not in row_index:
            sys.exit(f"ROLES names a row that does not exist: {t}: {st}")

NVERBS = 0
guard = BEARING / "bin" / "brg-guard"
if guard.exists():
    import subprocess

    try:
        out = subprocess.run(
            ["bash", str(guard), "--verbs"], capture_output=True, text=True, timeout=20
        )
        NVERBS = len([l for l in out.stdout.splitlines() if l.strip()])
    except (OSError, subprocess.SubprocessError):
        NVERBS = 0
if NVERBS == 0:
    sys.exit(
        "plugins/bearing/bin/brg-guard --verbs printed 0 verbs; the security section cannot state a count"
    )

n_rows = sum(len(r) for _, r in STAGES)
stack_ids = []
for p in sorted((p for d in SKILL_DIRS for p in d.glob("templates*/stack.json")), key=lambda q: (q.parent.parent.name, q.parent.name)):
    try:
        stack_ids.append(
            json.loads(p.read_text(encoding="utf-8")).get("id") or p.parent.parent.name
        )
    except json.JSONDecodeError:
        stack_ids.append(p.parent.parent.name)

def replace_between(path, start, end, body, label):
    text = path.read_text(encoding="utf-8")
    if start not in text or end not in text:
        sys.exit(f"markers {start} / {end} missing in {path.relative_to(ROOT)}")
    head, rest = text.split(start, 1)
    _, tail = rest.split(end, 1)
    path.write_text(f"{head}{start}\n{body}\n{end}{tail}", encoding="utf-8")
    print(label)


# docs/WORKFLOW.md: the stage tables and the reading notes.
wf = ROOT / "docs" / "WORKFLOW.md"
if wf.exists():
    parts = []
    for i, (title, rows) in enumerate(STAGES, 1):
        parts.append(
            f"## {i}. {title}\n\n| Stage | Skill | From | Output |\n| --- | --- | --- | --- |"
        )
        for stage, skill, src, out in rows:
            parts.append(f"| {stage} | `{skill}` | {src} | {out} |")
        parts.append("")
    parts.append("## How to read this map\n")
    for n in NOTES:
        parts.append(f"- {n}")
    parts.append("")
    replace_between(
        wf,
        "<!-- stages:start -->",
        "<!-- stages:end -->",
        "\n".join(parts),
        f"workflow: {n_rows} stage rows written to docs/WORKFLOW.md",
    )

# The skills map is no longer written into templates/repo/AGENTS.md and
# CLAUDE.md: both load on every turn, and the map is on demand from
# workflow and in docs/WORKFLOW.md.

# ---------------------------------------------------------------------------
# THE SITE'S DATA. The handbook site (site/) renders from one JSON file that is
# a pure function of the kit: the skills, the stage map and the four task
# flows (docs/flows.json). The flows file is validated here, so a flow that
# names a skill that does not exist fails make docs and make check rather
# than rendering a broken page.
FLOWS = ROOT / "docs" / "flows.json"
SITE_DATA = ROOT / "site" / "src" / "data" / "handbook.json"
known_names = {
    l.strip() for l in KNOWN.read_text(encoding="utf-8").splitlines() if l.strip() and not l.startswith("#")
} | BUILTIN | {"claude-security"}
skill_names = {s["name"] for s in skills}


def skill_ok(name):
    base = name.strip().split()[0].lstrip("/")
    return base in skill_names or base in known_names


flows = json.loads(FLOWS.read_text(encoding="utf-8"))["flows"] if FLOWS.exists() else []
if not flows:
    sys.exit("docs/flows.json: 0 flows, nothing to draw")
flow_ids = {f["id"] for f in flows}
bad, n_flow_steps = [], 0


RANKING = re.compile(r"\b(stronger|strongest|weaker|better than|beats?|no other installed)\b", re.I)


def walk_steps(fid, steps):
    global n_flow_steps
    for st in steps:
        k = st.get("kind")
        if k == "step":
            n_flow_steps += 1
            for key in ("id", "title", "skill", "pack", "does", "output", "why"):
                if not st.get(key):
                    bad.append(f"{fid}: step {st.get('id', '?')} has no {key}")
            if st.get("skill") and not skill_ok(st["skill"]):
                bad.append(f"{fid}: step {st.get('id')} names unknown skill {st['skill']}")
            # The public pages name what a step runs, never a ranking of
            # other packs' skills against it.
            if "alternates" in st:
                bad.append(f"{fid}: step {st.get('id')} has alternates; the published flows carry none")
            for key in ("does", "output", "why"):
                if RANKING.search(st.get(key, "")):
                    bad.append(f"{fid}: step {st.get('id')} {key} ranks skills: {RANKING.search(st[key]).group(0)!r}")
        elif k == "branch":
            if not st.get("question") or not st.get("options"):
                bad.append(f"{fid}: a branch needs a question and options")
            for o in st.get("options", []):
                walk_steps(fid, o.get("steps", []))
        elif k == "link":
            if st.get("flow") not in flow_ids:
                bad.append(f"{fid}: link to unknown flow {st.get('flow')}")
        elif k != "phase":
            bad.append(f"{fid}: unknown kind {k}")


for f in flows:
    walk_steps(f["id"], f["steps"])

# The default files per scope, with their contents read from templates/, so
# the page shows exactly what install.sh and onboard-repo write. Every template
# must be described; a new one without an entry fails here.
DEFAULT_FILES = ROOT / "docs" / "default-files.json"
default_files = json.loads(DEFAULT_FILES.read_text(encoding="utf-8"))["scopes"] if DEFAULT_FILES.exists() else []
if not default_files:
    bad.append("docs/default-files.json: 0 scopes, nothing to show")
described = set()
n_default = 0
for scope in default_files:
    for f in scope["files"]:
        n_default += 1
        for key in ("path", "purpose", "installedBy", "edit", "keep"):
            if not f.get(key):
                bad.append(f"docs/default-files.json: {f.get('path', '?')} has no {key}")
        src = f.get("source")
        if src:
            sp = ROOT / src
            if not sp.is_file():
                bad.append(f"docs/default-files.json: {f['path']} names a missing template {src}")
                continue
            described.add(src)
            f["content"] = sp.read_text(encoding="utf-8")
        elif not f.get("content") and not f.get("note"):
            bad.append(f"docs/default-files.json: {f['path']} has neither a source, content nor a note")
templates_on_disk = {
    str(p.relative_to(ROOT)) for p in (BEARING / "templates").rglob("*") if p.is_file() and p.name != ".gitkeep"
}
for missing in sorted(templates_on_disk - described):
    bad.append(f"docs/default-files.json: template {missing} is not described")

if bad:
    for b in bad:
        print(b, file=sys.stderr)
    sys.exit(f"site data: {len(bad)} problems in the flows or default files")

site_data = {
    "version": VERSION,
    "skills": skills,
    "categories": list(CATEGORY.keys()),
    "stages": [
        {"title": t, "when": STAGE_WHEN[t], "rows": [
            {"stage": r[0], "skill": r[1], "from": r[2], "output": r[3]} for r in rows
        ]} for t, rows in STAGES
    ],
    "notes": NOTES,
    "flows": flows,
    "defaultFiles": default_files,
    "config": [{"key": k, "meaning": m, "default": d} for k, m, d in CONFIG_KEYS],
    "roles": [{"role": r, "blurb": b, "rows": [{"stage": t, "row": s} for t, s in refs]} for r, b, refs in ROLES],
    "stacks": stack_ids,
    "guardVerbs": NVERBS,
    "walkthrough": WALKTHROUGH.read_text(encoding="utf-8") if WALKTHROUGH.exists() else "",
}
SITE_DATA.parent.mkdir(parents=True, exist_ok=True)
SITE_DATA.write_text(json.dumps(site_data, indent=1, ensure_ascii=False) + "\n", encoding="utf-8")
print(
    f"site data: {len(skills)} skills, {len(flows)} flows ({n_flow_steps} steps), "
    f"{n_default} default files written to {SITE_DATA.relative_to(ROOT)}"
)
