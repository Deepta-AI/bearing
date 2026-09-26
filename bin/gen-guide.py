#!/usr/bin/env python3
"""Generate the documents that derive from the skills in this repository:

  site/src/data/handbook.json   everything the handbook site renders
  docs/WORKFLOW.md              the stage tables between the markers

Every table comes from one source: the skill frontmatter (name,
description, invocation), CATEGORY, STAGES and ALTERNATES below, plus two
reviewed files: docs/flows.json (the four task flows) and
docs/comparisons.json (every Bearing skill against its best alternative).
Fails when zero skills are found, when a skill has no category, when a row
names more than one main skill, when an alternate or a flow names a skill
docs/known-skills.txt does not list, or when a skill has no verdict.

    gen-guide.py                        write every document
    gen-guide.py --write-known-skills   rewrite docs/known-skills.txt from
                                        the skills installed on this
                                        machine, then continue
    gen-guide.py --check-alternates     the default; kept as a flag so a
                                        caller can name the intent"""

import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
VERSION = (ROOT / "VERSION").read_text().strip()
KNOWN = ROOT / "docs" / "known-skills.txt"
WALKTHROUGH = ROOT / "docs" / "examples" / "walkthrough.md"

# Lanes that are planned but whose directory may not exist yet. A CATEGORY
# entry without a directory is skipped with a note, never a failure.
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

# The Bearing skills: every directory under skills/ that holds a SKILL.md.
# Membership in this set, not a name prefix, is what makes a name a Bearing skill.
existing = {
    p.name for p in (ROOT / "skills").iterdir() if (p / "SKILL.md").is_file()
}
absent = [s for s in CAT_OF if s not in existing]
for s in absent:
    print(f"note: {s} is in CATEGORY but has no skills/{s}/SKILL.md yet; skipped")

skills = []
for skill in sorted((ROOT / "skills").glob("*/SKILL.md")):
    text = skill.read_text(encoding="utf-8")
    m = re.search(r"^---\n(.*?)\n---", text, re.S)
    if not m:
        sys.exit(f"no frontmatter: {skill}")
    fm = m.group(1)
    name = re.search(r"^name: (.+)$", fm, re.M).group(1).strip()
    desc = re.search(r"^description: (.+)$", fm, re.M).group(1).strip()
    cmd = bool(re.search(r"^disable-model-invocation: true", fm, re.M))
    arg = re.search(r'^argument-hint: "?(.+?)"?$', fm, re.M)
    what, _, when = desc.partition(" Use when ")
    phrases = re.findall(r'"([^"]+)"', when)
    skills.append(
        {
            "name": name,
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
    {p.parent.parent.name for p in (ROOT / "skills").glob("*/templates*/stack.json")}
)

# Alternates a developer may pick instead of the Bearing skill, per skill.
# "(not installed)" marks a documented alternate the installer does not
# fetch; its install command is in docs/THIRD_PARTY.md.
ALTERNATES = {
    "prd": "create-prd (pm-skills); grilling then to-spec (mattpocock)",
    "backlog": "user-stories, job-stories (pm-skills); to-tickets (mattpocock)",
    "estimate": "sprint-plan (pm-skills)",
    "tracker-sync": "to-tickets (mattpocock); user-stories (pm-skills); glab or gh by hand when the surface is not enough",
    "spike": "gsd-spike; research (mattpocock)",
    "ab-experiment": "growthbook (official marketplace, not installed)",
    "tech-decision": "gsd-discuss-phase (GSD Core)",
    "adr": "documentation-and-adrs (addyosmani)",
    "explain-codebase": "gsd-map-codebase; /investigate (gstack) when the question is a bug",
    "architecture-diagram": "/diagram (gstack) for rendering",
    "high-level-design": "/plan-eng-review (gstack); gsd-spec-phase for the scope half",
    "low-level-design": "writing-plans (Superpowers) for the task half",
    "openapi-spec": "api-and-interface-design (addyosmani)",
    "api-versioning": "/review (gstack)",
    "auth": "/cso (gstack)",
    "background-jobs": "api-and-interface-design (addyosmani)",
    "webhooks": "/cso (gstack)",
    "feature-patterns": "none",
    "data-model": "domain-modeling (mattpocock) for the entity half",
    "deployment-architecture": "gsd-map-codebase (GSD Core)",
    "threat-model": "security-threat-model (openai/skills), run for the abuse path pass in step 4; gsd-secure-phase (GSD Core); differential-review (trailofbits) for diffs",
    "ux-flows": "/plan-design-review (gstack); shape (ui-craft); customer-journey-map (pm-skills)",
    "design-directions": "/design-shotgun (gstack, needs an OpenAI key); gsd-sketch",
    "design-system": "tokens (ui-craft); gsd-ui-phase; /design-consultation (gstack) for the prose",
    "screen-design": "craft and sddesign (ui-craft); /design-html (gstack); gsd-sketch",
    "themes": "tokens (ui-craft) for the dark mode audit; theme-factory (Anthropic, decks only)",
    "motion-design": "animate and delight (ui-craft); vercel-react-view-transitions; gsap-skills (greensock, not installed)",
    "design-critique": "/design-review (gstack) once the app runs in a browser; critique and finalize (ui-craft); gsd-ui-review; web-design-guidelines (Vercel)",
    "new-repo": "none",
    "onboard-repo": "none",
    "company-attribution": "none",
    "ci-pipeline": "/qa (gstack) test framework bootstrap; gha-security-review (getsentry) and agentic-actions-auditor (trailofbits) review the GitHub workflows in step 7",
    "git-hooks": "conventional-commit-message for the message rules",
    "observability": "otel-instrumentation (dash0); observability-and-instrumentation (addyosmani)",
    "logging": "observability-and-instrumentation (addyosmani); otel-instrumentation (dash0) for log and trace correlation",
    "health-checks": "/canary (gstack)",
    "analytics-events": "none",
    "i18n": "harden (ui-craft)",
    "feature-flags": "cloudflare (Cloudflare); growthbook (official marketplace, not installed)",
    "dependency-audit": "supply-chain-risk-auditor (trailofbits), run inside step 2 for npm, PyPI and Go risk; /cso (gstack) supply chain phase",
    "secrets": "/cso (gstack)",
    "license-compliance": "none",
    "privacy-review": "/cso (gstack)",
    "start-task": "using-git-worktrees (Superpowers)",
    "session-handoff": "gsd-pause-work; /context-save (gstack)",
    "task-report": "gsd-pause-work (GSD Core)",
    "definition-of-done": "verification-before-completion (Superpowers)",
    "docs-drift": "/document-release (gstack) after a ship, from the diff; gsd-docs-update (GSD Core)",
    "verify-deploy": "/canary (gstack) for a watch window on prod",
    "merge-request": "conventional-commit-message; /ship (gstack, stops at the push)",
    "release": "release-notes (pm-skills); changelog-automation (wshobson, not installed)",
    "app-store-release": "/ship (gstack)",
    "refactor": "improve-codebase-architecture (mattpocock) to find the targets",
    "tech-debt": "/health (gstack)",
    "test-cases": "test-scenarios (pm-skills); ai-test-generation (qa-skills); gsd-add-tests",
    "test-automation": "ai-test-generation (qa-skills); playwright-cli; gsd-add-tests; property-based-testing (trailofbits) for the property rows in step 3",
    "test-run": "playwright-cli; /qa and /qa-only (gstack)",
    "test-heal": "test-reliability, selector-drift-recovery (qa-skills); playwright-cli healing",
    "load-test": "k6 (Grafana), which load-test loads as its script engine; benchmark (gstack) for page weight only",
    "performance": "web-perf for Core Web Vitals in the browser",
    "resilience-testing": "none",
    "accessibility": "accessibility-audit, accessibility-scan, accessibility-inspect, accessibility-fix, accessibility-diff (AccessLint), the web engine inside it; audit (ui-craft); web-design-guidelines (Vercel)",
    "branch-review": "/review (gstack) directly, which gets the checklists from the session start but no independent verification; code-review (official, GitHub PRs); gsd-code-review",
    "vapt-report": "the claude-security or /cso report alone, with no threat model links and no release decision; insecure-defaults:audit (trailofbits) as an extra finder in step 2",
    "gate-audit": "none",
    "prose-lint": "clarify (ui-craft) for UI copy",
    "traceability": "gsd-audit-milestone (GSD Core)",
    "db-migration": "none",
    "runbook": "observability-and-instrumentation (addyosmani); document-generate (gstack)",
    "incident": "none",
    "postmortem": "/retro (gstack) for the weekly engineering retro",
    "on-call": "none",
    "cloud-cost": "none",
    "client-handover": "none",
    "client-deliverables": "docx (Anthropic) for one document written by hand; nothing builds the versioned folder pack",
    "genai-design": "gsd-ai-integration-phase (GSD Core)",
    "prompt-registry": "claude-api (Anthropic); langfuse (official marketplace, not installed) traces prompts but its plugin does not manage them",
    "llm-agent": "claude-api (Anthropic); agent-sdk-dev (official marketplace, not installed)",
    "rag": "claude-api (Anthropic)",
    "llm-eval": "gsd-eval-review (GSD Core); deepeval, mlflow, langfuse (official marketplace, not installed); huggingface-community-evals for public benchmarks of a trained checkpoint (huggingface-skills, not installed)",
    "llm-fine-tuning": "huggingface-llm-trainer for runs on Hugging Face Jobs, trl-training for the TRL command line (huggingface-skills, official marketplace, not installed)",
    "speech": "twilio-voice-conversation-relay for the Twilio phone leg only (twilio-developer-kit, official marketplace, not installed)",
    "computer-vision": "huggingface-vision-trainer for training on Hugging Face Jobs, fiftyone-model-evaluation and fiftyone-dataset-curation for error analysis and curation (official marketplace, not installed)",
    "tabular-ml": "none",
    "mcp-server": "build-mcp-server (mcp-server-dev, official); mcp-builder (Anthropic)",
    "llm-guardrails": "/cso (gstack)",
    "llm-gateway": "cloudflare (Cloudflare)",
    "react": "vercel-react-best-practices (pair, not replace)",
    "nextjs": "vercel-react-best-practices (pair, not replace)",
    "node": "none",
    "go": "golang-concurrency, golang-context, golang-error-handling, golang-testing, golang-security and the rest of cc-skills-golang (samber), loaded by go per job; go keeps the stack and gate",
    "python": "/review (gstack)",
    "data-pipeline": "none",
    "react-native": "expo-upgrade, expo-router (expo/skills), paired for SDK bumps and native navigation UI",
    "flutter": "flutter-fix-layout-issues, flutter-setup-declarative-routing, flutter-add-widget-test (flutter/agent-plugins), paired for those jobs; flutter-apply-architecture-best-practices for a repo already on ChangeNotifier",
    "android": "agp-9-upgrade, edge-to-edge, android-intent-security, r8-analyzer, android-testing-setup (android/skills), each for its platform job; navigation-3 only after an ADR",
    "ios": "swiftui-pro (twostraws), paired for SwiftUI views; /ios-qa (gstack) on a device",
    "infra": "terraform-test, terraform-refactor-module, terraform-style-guide (HashiCorp), loaded by infra for tests, module refactors and HCL style; never their apply",
    "database": "supabase-postgres-best-practices (Supabase) on Supabase projects; /review (gstack)",
    "workflow": "gsd-next, gsd-progress; start (ui-craft) for the design lane",
    "autopilot": "gsd-autonomous (GSD) runs planned phases unattended but knows no Bearing stage gates or decision digest",
    "doctor": "none",
    "upgrade-tools": "/gstack-upgrade (gstack)",
    "new-skill": "skill-creator (Anthropic) runs the evals this skill hands it; writing-skills (Superpowers)",
    "harness-setup": "npx skills add <kit> --all -a <agent> by hand; each harness's own rules files",
}
no_alt = sorted(existing - set(ALTERNATES))
if no_alt:
    sys.exit(f"skills without an ALTERNATES entry: {no_alt}")
bad_keys = sorted(set(ALTERNATES) - existing - FUTURE)
if bad_keys:
    sys.exit(f"ALTERNATES names skills that do not exist: {bad_keys}")

# One main skill per row. Columns: stage, main skill, pack, output, alternate.
STAGES = [
    (
        "Discover",
        [
            (
                "Pressure-test the idea",
                "/office-hours",
                "gstack",
                "a go or no-go with reasons",
                "/plan-ceo-review (gstack); pre-mortem (pm-skills)",
            ),
            (
                "Timeboxed investigation",
                "spike",
                "bearing",
                "docs/spikes/<date>-<name>.md: the question, the timebox, an answer, a recommendation",
                "gsd-spike; research (mattpocock); prototype (mattpocock) when the question is how a screen or a state machine feels",
            ),
            (
                "Understand a codebase",
                "explain-codebase",
                "bearing",
                "entry points, module graph, one request's flow, the ten files that matter, every claim at path:line",
                "gsd-map-codebase; /investigate (gstack) when the question is a bug",
            ),
            (
                "Normalise the PRD",
                "prd",
                "bearing",
                "docs/product/PRD.md with REQ-nnn statements",
                "create-prd (pm-skills); grilling then to-spec (mattpocock)",
            ),
            (
                "Backlog from the PRD",
                "backlog",
                "bearing",
                "epics, US- stories with AC-, coverage matrix, user flows",
                "user-stories, job-stories (pm-skills); to-tickets (mattpocock)",
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
                "sprint-plan (pm-skills)",
            ),
            (
                "Tickets in the tracker (optional)",
                "tracker-sync",
                "bearing",
                "tickets linked to stories in Jira, GitLab, GitHub or any REST tracker; with BEARING_TRACKER=none the step is skipped with a note",
                "none",
            ),
            (
                "Debt register",
                "tech-debt",
                "bearing",
                "docs/DEBT.md: interest, principal, trigger and owner per row, seeded from markers, suppressions and skipped tests",
                "/health (gstack) for a code quality score tracked over time",
            ),
            (
                "Plan review",
                "/plan-eng-review",
                "gstack",
                "reviewed plan",
                "/plan-devex-review (gstack); /devex-review (gstack) for a live developer experience audit; gsd-plan-phase",
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
                "none",
            ),
            (
                "Boundary decision",
                "adr",
                "bearing",
                "docs/adr/ADR-nnnn",
                "documentation-and-adrs (addyosmani)",
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
                "/diagram (gstack) to render",
            ),
            (
                "High level design",
                "high-level-design",
                "bearing",
                "docs/design/<x>-hld.md",
                "gsd-spec-phase",
            ),
            (
                "Low level design",
                "low-level-design",
                "bearing",
                "docs/design/<x>-lld.md",
                "writing-plans (Superpowers); codebase-design (mattpocock) for deep modules and interface design",
            ),
            (
                "API contract",
                "openapi-spec",
                "bearing",
                "api/openapi.yaml and a drift report",
                "api-and-interface-design (addyosmani)",
            ),
            (
                "API versioning and retirement",
                "api-versioning",
                "bearing",
                "versioning choice, Deprecation and Sunset headers, consumer inventory, a removal gate counted from logs",
                "none",
            ),
            (
                "Authentication and authorisation",
                "auth",
                "bearing",
                "session or token choice with reasons, permission matrix, IDOR checks, tenant isolation, token rotation",
                "none",
            ),
            (
                "Background work",
                "background-jobs",
                "bearing",
                "queue, cron or outbox with idempotency keys, retries, dead letters, graceful shutdown",
                "none",
            ),
            (
                "Webhooks",
                "webhooks",
                "bearing",
                "signed inbound handlers with a replay window; outbound catalogue with retries and dead letters",
                "none",
            ),
            (
                "Known problem, known pattern",
                "feature-patterns",
                "bearing",
                "uploads, search, realtime, cache, rate limit, payments, notifications, multitenancy: decision, data model, failure modes, tests",
                "none",
            ),
            (
                "Data model",
                "data-model",
                "bearing",
                "ERD, schema per store, migration plan",
                "domain-modeling (mattpocock)",
            ),
            (
                "Deployment architecture",
                "deployment-architecture",
                "bearing",
                "environments, topology, rollback, DR",
                "none",
            ),
            (
                "Threat model",
                "threat-model",
                "bearing",
                "STRIDE table with mitigations",
                "gsd-secure-phase (GSD Core) to verify each mitigation in a GSD phase; security-threat-model (openai/skills), which threat-model runs for the abuse path pass",
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
                "/plan-design-review (gstack); shape (ui-craft); customer-journey-map (pm-skills)",
            ),
            (
                "Design direction",
                "/design-consultation",
                "gstack",
                "DESIGN.md with aesthetic, type, colour, spacing, motion",
                "brief (ui-craft); frontend-design (Anthropic)",
            ),
            (
                "Three variants to choose from",
                "design-directions",
                "bearing",
                "three distinct HTML variants, comparison board, approved.json",
                "/design-shotgun (gstack, OpenAI key); gsd-sketch; prototype (mattpocock) for variants on a live route",
            ),
            (
                "Design system and tokens",
                "design-system",
                "bearing",
                "tokens.json, per-stack bindings, component contract, design lint",
                "tokens (ui-craft); gsd-ui-phase; extract (ui-craft) to pay down literal values into tokens",
            ),
            (
                "Screen designs",
                "screen-design",
                "bearing",
                "one HTML prototype per screen with every state, redlines",
                "craft, sddesign (ui-craft); /design-html (gstack)",
            ),
            (
                "Theming",
                "themes",
                "bearing",
                "themes as token overrides, contrast lint, preview page",
                "tokens (ui-craft); theme-factory (Anthropic, decks only)",
            ),
            (
                "Motion and animation",
                "motion-design",
                "bearing",
                "motion spec, hero and banner moments, reduced-motion paths",
                "animate, delight (ui-craft); vercel-react-view-transitions",
            ),
            (
                "Design review and iteration",
                "design-critique",
                "bearing",
                "ten scored categories with evidence on prototypes or a URL, an AI-slop detector, approved fixes, a re-score; while only prototypes exist this is the main choice, and once the app runs in a browser switch to /design-review",
                "/design-review (gstack, running app); heuristic (ui-craft) for a usability pass; critique, finalize (ui-craft); gsd-ui-review",
            ),
            (
                "Copy and clarity",
                "clarify",
                "ui-craft",
                "UX copy reviewed: buttons, errors, empty states, form hints",
                "prose-lint for documents, MR text and commits",
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
                "none",
            ),
            (
                "Prompts",
                "prompt-registry",
                "bearing",
                "versioned registry with tests and eval scores",
                "claude-api (Anthropic) for the prompt wording audit, which prompt-registry calls",
            ),
            (
                "Retrieval",
                "rag",
                "bearing",
                "ingestion, pgvector schema, retriever with citations",
                "none",
            ),
            (
                "Agents",
                "llm-agent",
                "bearing",
                "tool registry, bounded loop, kill switch",
                "claude-api (Anthropic) for agent and tool use design; agent-sdk-dev (official marketplace, not installed)",
            ),
            (
                "Tools for models",
                "mcp-server",
                "bearing",
                "MCP server with schema-checked tools, both transports, auth, a test per tool, the harness registration",
                "build-mcp-server (mcp-server-dev, official); mcp-builder (Anthropic)",
            ),
            (
                "Safety",
                "llm-guardrails",
                "bearing",
                "policy file, input, tool and output checks",
                "none",
            ),
            (
                "Every model call",
                "llm-gateway",
                "bearing",
                "routing, retries, caching, cost, tracing",
                "none",
            ),
            (
                "Is it good enough",
                "llm-eval",
                "bearing",
                "golden set, graders, CI regression gate",
                "deepeval, mlflow (official marketplace, not installed)",
            ),
            (
                "Prompting is not enough",
                "llm-fine-tuning",
                "bearing",
                "data prep, recipe, GPU check, smoke run, vLLM serving, model card",
                "huggingface-llm-trainer, trl-training (official marketplace, not installed)",
            ),
            (
                "Speech and voice",
                "speech",
                "bearing",
                "WER per language, latency per stage, barge-in, audio privacy",
                "twilio-voice-conversation-relay for the phone leg (official marketplace, not installed)",
            ),
            (
                "Vision",
                "computer-vision",
                "bearing",
                "group-safe splits, AUROC or mAP, threshold from costs, serving latency",
                "huggingface-vision-trainer, fiftyone-model-evaluation (official marketplace, not installed)",
            ),
            (
                "Classical ML and forecasting",
                "tabular-ml",
                "bearing",
                "leakage check, baseline gate, calibration, explanations, drift",
                "none",
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
                "none",
            ),
            (
                "Existing repository",
                "onboard-repo",
                "bearing",
                "standard files added, conflicts listed beside the file as .bearing-new",
                "none",
            ),
            (
                "Attribute to a company",
                "company-attribution",
                "bearing",
                ".bearing/company.json, LICENSE, NOTICE, CODEOWNERS",
                "none",
            ),
            (
                "Pipeline",
                "ci-pipeline",
                "bearing",
                "the pipeline file for the configured git host, every job calling a make target",
                "none",
            ),
            (
                "Git hooks",
                "git-hooks",
                "bearing",
                ".githooks wired",
                "conventional-commit-message",
            ),
            (
                "Observability stack",
                "observability",
                "bearing",
                "OpenTelemetry, dashboards, alerts, SLOs",
                "otel-instrumentation (dash0)",
            ),
            (
                "Logging",
                "logging",
                "bearing",
                "structured logs, HTTP logging behind LOG_HTTP",
                "otel-instrumentation (dash0)",
            ),
            (
                "Health monitoring",
                "health-checks",
                "bearing",
                "healthz, readyz, synthetic probes",
                "none",
            ),
            (
                "Analytics",
                "analytics-events",
                "bearing",
                "event sheet, tracking plan, SDK wiring",
                "none",
            ),
            (
                "Internationalisation",
                "i18n",
                "bearing",
                "string catalogs, make i18n-check",
                "none",
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
                "none",
            ),
            (
                "Vague request",
                "brainstorming",
                "Superpowers",
                "a spec, triggers on its own",
                "gsd-spec-phase; grilling (mattpocock); /spec (gstack)",
            ),
            (
                "Plan the change",
                "writing-plans",
                "Superpowers",
                "tasks a fresh session can run",
                "gsd-plan-phase; to-tickets (mattpocock)",
            ),
            (
                "Multi-session work",
                "gsd-plan-phase",
                "GSD Core",
                "phases with state files; gsd-execute-phase runs them",
                "none",
            ),
            (
                "Understand before changing",
                "explain-codebase",
                "bearing",
                "the subsystem mapped, every claim at path:line, the files a change would touch",
                "gsd-map-codebase",
            ),
            (
                "Test cases first",
                "test-cases",
                "bearing",
                "TC-nnnn cases traced to criteria",
                "test-scenarios (pm-skills); ai-test-generation (qa-skills)",
            ),
            (
                "Write code",
                "test-driven-development",
                "Superpowers",
                "tested code; stack skills load on their own",
                "vercel-react-best-practices alongside react; unhappy (ui-craft) for error, conflict and offline states in UI code",
            ),
            (
                "Restructure without changing behaviour",
                "refactor",
                "bearing",
                "tests green first, one mechanical transform per commit, make check between, a diff ceiling",
                "improve-codebase-architecture (mattpocock) to find the targets; codebase-design (mattpocock) for the target shape",
            ),
            (
                "Something is slow",
                "performance",
                "bearing",
                "before and after numbers from the stack's profiler, docs/performance/<name>.md",
                "web-perf for Core Web Vitals; /benchmark (gstack) for web performance baselines and regressions",
            ),
            (
                "A secret to add or rotate",
                "secrets",
                "bearing",
                "docs/security/SECRETS.md inventory, rotation per type, leak response, gitleaks pre-commit",
                "none",
            ),
            (
                "Schema change",
                "db-migration",
                "bearing",
                "migration with a tested Down",
                "none",
            ),
            (
                "Feature flag",
                "feature-flags",
                "bearing",
                "flag with owner and removal task",
                "growthbook (official marketplace, not installed)",
            ),
            (
                "Feature analytics",
                "analytics-events",
                "bearing",
                "events wired and tested",
                "none",
            ),
            (
                "Broken, no obvious cause",
                "systematic-debugging",
                "Superpowers",
                "root cause, then fix",
                "diagnosing-bugs (mattpocock) for a regression: a red loop, bisection, ranked hypotheses; gsd-debug; /investigate (gstack); /freeze (gstack) to hold edits to one directory while debugging; debugging-and-error-recovery (addyosmani)",
            ),
            (
                "Merge conflict",
                "resolving-merge-conflicts",
                "mattpocock",
                "both sides' intent kept and the project's checks green; you start the rebase",
                "none",
            ),
            (
                "Pause mid-task",
                "session-handoff",
                "bearing",
                ".bearing/state/<branch>.md (local detail) and docs/progress/<ID>.md (the shared summary)",
                "gsd-pause-work; /context-save (gstack)",
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
                "ai-test-generation (qa-skills); playwright-cli; gsd-add-tests",
            ),
            (
                "Run tests, pass/fail report",
                "test-run",
                "bearing",
                "docs/testing/reports/<date>.md and .json",
                "playwright-cli; /qa-only (gstack)",
            ),
            (
                "Docs still match the code",
                "docs-drift",
                "bearing",
                "a drift report with counts: broken paths, make targets and config names, docs older than their code; code is the truth for what it does, the doc for what was intended",
                "/document-release (gstack) after a ship; gsd-docs-update",
            ),
            (
                "Self-heal tests",
                "test-heal",
                "bearing",
                "healed tests, quarantine, healing log, regressions kept red",
                "test-reliability, selector-drift-recovery (qa-skills)",
            ),
            (
                "Load and performance",
                "load-test",
                "bearing",
                "k6 scripts with thresholds",
                "none",
            ),
            (
                "Resilience",
                "resilience-testing",
                "bearing",
                "fault plan against the HLD failure-mode table, a dated restore drill, a DR test with measured RTO and RPO",
                "none",
            ),
            (
                "Accessibility",
                "accessibility",
                "bearing",
                "findings fixed or listed",
                "audit (ui-craft); web-design-guidelines (Vercel)",
            ),
            (
                "Privacy review",
                "privacy-review",
                "bearing",
                "data map, deletion wired to it, DSAR paths, a DPIA, a PII lint",
                "none",
            ),
            (
                "Open-source compliance",
                "license-compliance",
                "bearing",
                "CycloneDX SBOM, licence inventory gated by policy with counts, NOTICE-THIRD-PARTY.md",
                "none",
            ),
            (
                "Definition of done",
                "definition-of-done",
                "bearing",
                "verdict with evidence",
                "verification-before-completion (Superpowers); gsd-verify-work (GSD Core) for a user acceptance pass",
            ),
            (
                "Code review",
                "branch-review",
                "bearing",
                "gstack /review with the stack checklists, then an independent verifier on every Critical and High",
                "/review (gstack) alone, without the independent verification; code-review (mattpocock) for a spec axis against the issue; differential-review (trailofbits) for blast radius and removed security code; code-review (official, GitHub); gsd-code-review"),
            (
                "Security review",
                "/cso",
                "gstack",
                "a verified report under .gstack/security-reports/ (use --diff on a branch)",
                "claude-security (official, deeper: three verifiers per finding, slower); /security-review (built in); differential-review (trailofbits); gsd-secure-phase",
            ),
            (
                "Browser QA",
                "/qa",
                "gstack",
                "QA report",
                "/qa-only (gstack); playwright-cli",
            ),
            ("Gates are real", "gate-audit", "bearing", "per-gate table", "none"),
            (
                "Traceability",
                "traceability",
                "bearing",
                "docs/traceability.md, zero gaps",
                "none",
            ),
            (
                "Report back",
                "task-report",
                "bearing",
                "Changed, Verified, Not done, Noticed",
                "none",
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
                "conventional-commit-message; /ship (gstack, stops at the push)",
            ),
            (
                "Ticket update (optional)",
                "tracker-sync",
                "bearing",
                "ticket moved, MR linked; skipped with a note when BEARING_TRACKER is none",
                "none",
            ),
            (
                "Release",
                "release",
                "bearing",
                "CHANGELOG, version, tag command",
                "release-notes (pm-skills)",
            ),
            (
                "Publish a package or CLI",
                "release",
                "bearing",
                "with --package: API diff since the last tag, semver from the diff, pack check, provenance, the publish command printed",
                "release-notes (pm-skills)",
            ),
            (
                "App Store or Play submission",
                "app-store-release",
                "bearing",
                "build numbers, listing, tracks, phased rollout with halt rules, every store command printed",
                "none",
            ),
            (
                "Experiment on a flag",
                "ab-experiment",
                "bearing",
                "hypothesis, primary and guardrail metrics, sample size, exposure events, stopping rules",
                "growthbook (official marketplace, not installed)",
            ),
            ("Release docs", "/document-release", "gstack", "docs updated", "none"),
            (
                "Security scan before production",
                "claude-security",
                "official",
                "CLAUDE-SECURITY-<ts>/ with verified findings, SARIF and the scanned commit",
                "/cso --comprehensive (gstack, faster)",
            ),
            (
                "VAPT report",
                "vapt-report",
                "bearing",
                "docs/security/VAPT-<version>.md written from the scanner findings, tied to the threat model, with the release decision",
                "none",
            ),
            (
                "Dependencies",
                "dependency-audit",
                "bearing",
                "audit, upgrade plan, Renovate config",
                "none",
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
                "document-generate (gstack)",
            ),
            ("Incident", "incident", "bearing", "live incident doc, comms", "none"),
            (
                "After the incident",
                "postmortem",
                "bearing",
                "blameless postmortem, follow-ups",
                "/retro (gstack) for the weekly engineering retro",
            ),
            (
                "On-call",
                "on-call",
                "bearing",
                "rotation, escalation, alert routing by severity, error-budget policy, weekly review",
                "none",
            ),
            (
                "Cloud cost",
                "cloud-cost",
                "bearing",
                "attribution per service and environment, top ten lines, cuts, a monthly cadence",
                "none",
            ),
            (
                "Verify the deploy",
                "verify-deploy",
                "bearing",
                "docs/releases/verify-<env>-<time>.md from docs/environments.md: readiness, health, the deployed version against the tag, smoke checks, a verdict and the rollback sentence",
                "/canary (gstack) for a watch window on prod",
            ),
            ("Canary after deploy", "/canary", "gstack", "canary report", "none"),
            ("Weekly retro", "/retro", "gstack", "retro notes from the week's commits and shipping", "none"),
            (
                "Handover to the client",
                "client-handover",
                "bearing",
                "docs/handover/HANDOVER.md: environments, access inventory without values, deploy, runbooks, debt, licences",
                "none",
            ),
            (
                "Client documentation pack",
                "client-deliverables",
                "bearing",
                "deliverables/<Project>_ProjectDocumentation/: twelve folders, each artifact as Markdown, CSV and <Project>_<Artifact>_v<N>.docx with cover and history, README of current versions, CHANGELOG, delivery checklist workbook",
                "docx (Anthropic) for a single document",
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
                "gsd-autonomous (GSD)",
            ),
            (
                "Not sure what comes next",
                "workflow",
                "bearing",
                "the stage you are in, what is in flight (docs/progress/), the next skill, and whether the work is one agent, bounded tasks or parallel subagents",
                "gsd-next; start (ui-craft)",
            ),
            (
                "Something missing",
                "doctor",
                "bearing",
                "checks with counts and fixes",
                "none",
            ),
            (
                "Update the packs",
                "upgrade-tools",
                "bearing",
                "versions before and after",
                "none",
            ),
            (
                "A new repeatable procedure",
                "new-skill",
                "bearing",
                "a Bearing skill on the kit conventions, lints passing, handed to skill-creator for its evals",
                "writing-skills (Superpowers)",
            ),
            (
                "Measure a skill",
                "skill-creator",
                "Anthropic",
                "evals/evals.json, with-skill runs against a baseline, a benchmark, a tuned description",
                "writing-skills (Superpowers) pressure tests",
            ),
            (
                "Another coding harness",
                "harness-setup",
                "bearing",
                "rules, pointer files, hook adapters and skills for Cursor, Codex, Gemini CLI, Copilot, OpenCode, Windsurf, Cline, Zed and Kiro",
                "npx skills add by hand",
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
    "One main per row. The Skill column names exactly one skill; everything else a developer may use for that step is in the Alternate column, whatever pack it comes from. A Bearing skill is main only where nothing better was found.",
    "analytics-events serves two rows: under Set up the repository it designs the sheet and wires the SDK once; under Build a task it adds one feature's events against that sheet. Same skill, two moments.",
    "explain-codebase serves two rows as well: Discover (a repository you do not know) and Build a task (the subsystem you are about to change).",
    "tracker-sync appears under Plan and under Ship: ticket creation first, then the status and the MR link. With BEARING_TRACKER=none both rows are skipped with a note; rest (any server speaking the REST tracker protocol) is one adapter among none, jira, gitlab and github (docs/TRACKERS.md).",
    "Design review has two mains by time, not by taste: design-critique while only prototypes exist, gstack /design-review once the app runs in a browser.",
    '"Not this": an alternate marked (not installed) is documented with its install command in docs/THIRD_PARTY.md and is not fetched by the installer; an alternate that says "stops at the push" or "needs a key" carries that limit for a reason.',
]

for title, rows in STAGES:
    for row in rows:
        if len(row) != 5:
            sys.exit(f"stage row has {len(row)} fields, expected 5: {row}")
        if "," in row[1]:
            sys.exit(f"more than one main skill in row '{row[0]}' ({title}): {row[1]}")
    if title not in STAGE_WHEN:
        sys.exit(f"STAGE_WHEN lacks an entry for stage '{title}'")

# ---------------------------------------------------------------- known skills
PACKS = {
    "pm-skills",
    "ui-craft",
    "qa-skills",
    "mattpocock",
    "addyosmani",
    "dash0",
    "trailofbits",
    "openai/skills",
    "insecure-defaults",
    "getsentry",
    "android",
    "flutter",
    "samber",
    "cc-skills-golang",
    "hashicorp",
    "supabase",
    "expo",
    "grafana",
    "greensock",
    "wshobson",
    "gstack",
    "superpowers",
    "gsd",
    "core",
    "official",
    "marketplace",
    "anthropic",
    "vercel",
    "built",
    "in",
    "mcp-server-dev",
    "accesslint",
}
SINGLE_WORD = {
    "brief",
    "tokens",
    "shape",
    "craft",
    "sddesign",
    "critique",
    "finalize",
    "animate",
    "delight",
    "polish",
    "harden",
    "audit",
    "clarify",
    "bolder",
    "quieter",
    "redesign",
    "start",
    "retro",
    "grilling",
    "research",
    "brainstorming",
    "langfuse",
    "deepeval",
    "mlflow",
    "growthbook",
    "playwright",
    "context7",
}
BUILTIN = {"security-review", "simplify"}  # harness built-ins, not skill folders
NAME_RE = re.compile(r"(?<![\w/-])(/?)([a-z][a-z0-9]*(?:-[a-z0-9]+)*)(?![\w-])")


def names_in(text):
    """Skill names in free text: a leading slash always counts, a hyphenated
    lowercase token counts unless it is a pack name, and single words count
    only when SINGLE_WORD lists them. Yields (name, exempt)."""
    for segment in re.split(r"[;]", text):
        exempt = "not installed" in segment
        for slash, tok in NAME_RE.findall(segment):
            if tok in existing or tok in PACKS:
                continue
            if slash or "-" in tok or tok in SINGLE_WORD or tok.startswith("gsd"):
                yield tok, exempt


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


def check_alternates():
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
    checked, exempt, unknown, own_bad = 0, 0, [], []
    for skill, text in ALTERNATES.items():
        for name, ex in names_in(text):
            checked += 1
            if ex:
                exempt += 1
            elif name not in known and name not in BUILTIN:
                unknown.append(f"{name} (ALTERNATES[{skill}])")
    for title, rows in STAGES:
        for stage, main, src, out, alt in rows:
            if src == "bearing" or main in existing:
                if main not in existing:
                    own_bad.append(f"{main} ({title}: {stage})")
            else:
                checked += 1
                name = main.lstrip("/")
                if name not in known and name not in BUILTIN:
                    unknown.append(f"{main} (main, {title}: {stage})")
            for name, ex in names_in(alt):
                checked += 1
                if ex:
                    exempt += 1
                elif name not in known and name not in BUILTIN:
                    unknown.append(f"{name} ({title}: {stage})")
    if checked == 0:
        sys.exit("alternates: 0 names checked")
    if unknown or own_bad:
        for u in unknown:
            print(f"unknown skill name: {u}", file=sys.stderr)
        for u in own_bad:
            print(f"unknown Bearing skill: {u}", file=sys.stderr)
        sys.exit(
            f"alternates: {checked} names checked against {len(known)} known, {len(unknown) + len(own_bad)} unknown"
        )
    print(
        f"alternates: {checked} names checked against {len(known)} known skills, {exempt} marked not installed, 0 unknown"
    )


argv = sys.argv[1:]
if "--write-known-skills" in argv:
    found = scan_installed()
    if not found:
        sys.exit("known skills: 0 found on this machine; nothing written")
    KNOWN.write_text(
        "# Skill names installed on the maintainer's machine, one per line, sorted.\n"
        "# Generated by bin/gen-guide.py --write-known-skills; the generator checks\n"
        "# every alternate in the workflow tables against this list.\n"
        + "\n".join(found)
        + "\n",
        encoding="utf-8",
    )
    print(f"known skills: {len(found)} written to {KNOWN.relative_to(ROOT)}")
check_alternates()


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
guard = ROOT / "bin" / "brg-guard"
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
        "bin/brg-guard --verbs printed 0 verbs; the security section cannot state a count"
    )

n_rows = sum(len(r) for _, r in STAGES)
stack_ids = []
for p in sorted((ROOT / "skills").glob("*/templates*/stack.json")):
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
            f"## {i}. {title}\n\n| Stage | Main skill | From | Output | Alternate |\n| --- | --- | --- | --- | --- |"
        )
        for stage, skill, src, out, alt in rows:
            parts.append(f"| {stage} | `{skill}` | {src} | {out} | {alt or 'none'} |")
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
# a pure function of the kit: the skills, the stage map, the four task flows
# (docs/flows.json) and every Bearing skill's verdict against its best alternative
# (docs/comparisons.json). Both hand-kept files are validated here, so a flow
# that names a skill that does not exist, or a skill with no verdict, fails
# make docs and make check rather than rendering a broken page.
FLOWS = ROOT / "docs" / "flows.json"
COMPARISONS = ROOT / "docs" / "comparisons.json"
SITE_DATA = ROOT / "site" / "src" / "data" / "handbook.json"
VERDICTS = {"bearing-stronger", "alternative-stronger", "different-job", "no-alternative", "unverified"}
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
            for alt in st.get("alternates", []):
                if not skill_ok(alt.get("skill", "")):
                    bad.append(f"{fid}: step {st.get('id')} alternate names unknown skill {alt.get('skill')}")
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

comparisons = json.loads(COMPARISONS.read_text(encoding="utf-8")) if COMPARISONS.exists() else {}
for name, c in comparisons.items():
    if name not in skill_names:
        bad.append(f"docs/comparisons.json: {name} is not a skill")
    elif c.get("verdict") not in VERDICTS:
        bad.append(f"docs/comparisons.json: {name} verdict {c.get('verdict')!r}")
    elif c.get("best_alternative") and c["verdict"] != "unverified":
        # The best alternative is named by what a person types (invoke);
        # it must be a known skill and must appear in the map's alternates,
        # so the handbook's skill page and the workflow map never disagree.
        inv = c["best_alternative"].get("invoke", "")
        if not inv or not skill_ok(inv):
            bad.append(f"docs/comparisons.json: {name} best_alternative.invoke {inv!r} is not a known skill")
        elif not re.search(r"(?<![\w/-])/?" + re.escape(inv.lstrip("/")) + r"(?![\w-])", ALTERNATES.get(name, "")):
            bad.append(f"ALTERNATES[{name}] does not name its best alternative {inv} (docs/comparisons.json)")
missing_cmp = sorted(skill_names - set(comparisons))
if COMPARISONS.exists() and missing_cmp:
    bad.append(f"docs/comparisons.json: no verdict for {', '.join(missing_cmp)}")
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
    str(p.relative_to(ROOT)) for p in (ROOT / "templates").rglob("*") if p.is_file() and p.name != ".gitkeep"
}
for missing in sorted(templates_on_disk - described):
    bad.append(f"docs/default-files.json: template {missing} is not described")

if bad:
    for b in bad:
        print(b, file=sys.stderr)
    sys.exit(f"site data: {len(bad)} problems in the flows, comparisons or default files")

site_data = {
    "version": VERSION,
    "skills": skills,
    "categories": list(CATEGORY.keys()),
    "stages": [
        {"title": t, "when": STAGE_WHEN[t], "rows": [
            {"stage": r[0], "skill": r[1], "from": r[2], "output": r[3], "alternate": r[4]} for r in rows
        ]} for t, rows in STAGES
    ],
    "alternates": ALTERNATES,
    "notes": NOTES,
    "flows": flows,
    "comparisons": comparisons,
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
    f"{len(comparisons)} comparisons, {n_default} default files written to {SITE_DATA.relative_to(ROOT)}"
)
