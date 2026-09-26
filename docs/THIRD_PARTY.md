# What comes from where

Bearing works alongside open-source packs: some workflow steps call a
skill from one of them, and Bearing adds its own gates around it. Which
skill each stage runs is in [WORKFLOW.md](WORKFLOW.md). Which packs land on a machine depends on the
installer profile (`install.sh --profile minimal|standard|full`):

| Profile | Installs |
| --- | --- |
| `minimal` | the Bearing plugin and `~/.config/bearing/bearing.env` only |
| `standard` (default) | minimal plus Superpowers, gstack and GSD Core |
| `full` | standard plus every row below marked "full" (`plugins/bearing/bin/brg-install-packs`) |

The generator checks every skill a stage row or a flow step names from
another pack against `known-skills.txt`, the list of skill names found on
the maintainer's machine.

## Installed by profile

| Pack | Profile | Install | Licence | Used for |
| --- | --- | --- | --- | --- |
| Superpowers (obra) | standard | `claude plugin install superpowers@claude-plugins-official` | MIT | brainstorming (auto), writing-plans, executing-plans, test-driven-development, systematic-debugging, verification-before-completion, writing-skills |
| gstack (garrytan) | standard | fetch at the pinned commit into `~/.claude/skills/gstack` and `./setup` | MIT | /office-hours, /plan-ceo-review, /plan-eng-review, /plan-devex-review, /plan-design-review, /design-consultation, /design-review, /design-html, /review, /investigate, /qa, /qa-only, /browse, /cso, /health, /retro, /canary, /document-release, /document-generate, /diagram, /context-save, /spec |
| GSD Core (open-gsd) | standard | `npx @opengsd/gsd-core@1.14.0 --global --claude` | MIT | gsd-spec-phase, gsd-plan-phase, gsd-execute-phase, gsd-verify-work, gsd-pause-work, gsd-debug, gsd-code-review, gsd-add-tests, gsd-sketch, gsd-ui-phase, gsd-ui-review, gsd-next, gsd-spike, gsd-map-codebase |
| frontend-design (Anthropic, official marketplace) | full | `claude plugin install frontend-design@claude-plugins-official` | Apache-2.0 | the anti-generic design doctrine behind the design lane |
| code-review (Anthropic, official) | full | `claude plugin install code-review@claude-plugins-official` | Apache-2.0 | multi-reviewer, confidence-scored PR review (GitHub PRs and `gh`) |
| claude-security (Anthropic, official) | full | `claude plugin install claude-security@claude-plugins-official` | Apache-2.0 | deep vulnerability scan with a verifier panel and patch files |
| mattpocock-skills (official) | full | `claude plugin install mattpocock-skills@claude-plugins-official` | MIT | grilling, to-spec, to-tickets, research, domain-modeling, improve-codebase-architecture, diagnosing-bugs |
| mcp-server-dev (Anthropic, official) | full | `claude plugin install mcp-server-dev@claude-plugins-official` | Apache-2.0 | build-mcp-server, for "tools for models" |
| playwright (Microsoft, official) | full | `claude plugin install playwright@claude-plugins-official` | Apache-2.0 | the Playwright MCP server for browser automation |
| playwright-cli skill (Microsoft) | full | `npx @playwright/cli@0.1.21 install --skills -g` | Apache-2.0 | run, debug, generate and heal Playwright tests, traces, video |
| ui-craft (educlopez) | full | `npx skills@1.7.0 add educlopez/ui-craft#<commit> -a claude-code -g -y` | MIT | brief, tokens, shape, craft, sddesign, critique, finalize, animate, delight, polish, harden, audit, clarify (copy review), bolder, quieter, redesign, start |
| Vercel agent-skills | full | `npx skills@1.7.0 add vercel-labs/agent-skills#<commit> --skill <name> -a claude-code -g -y` | see repository | vercel-react-best-practices, vercel-react-view-transitions, web-design-guidelines |
| pm-skills (phuryn), ten of its skills | full | `npx skills@1.7.0 add phuryn/pm-skills#<commit> --skill create-prd ... -a claude-code -g -y` | MIT | create-prd, user-stories, job-stories, test-scenarios, release-notes, prioritization-frameworks, sprint-plan, pre-mortem, customer-journey-map, outcome-roadmap (not its retro: installed as `retro`, it takes the name gstack's `/retro` needs) |
| addyosmani/agent-skills, four skills | full | `npx skills@1.7.0 add addyosmani/agent-skills#<commit> --skill <name> -a claude-code -g -y` | MIT | documentation-and-adrs, api-and-interface-design, observability-and-instrumentation, debugging-and-error-recovery |
| dash0 agent-skills | full | `npx skills@1.7.0 add dash0hq/agent-skills#<commit> --skill otel-instrumentation -a claude-code -g -y` | Apache-2.0 | OpenTelemetry instrumentation with log and trace correlation |
| qa-skills (petrkindlmann), three skills | full | `npx skills@1.7.0 add petrkindlmann/qa-skills#<commit> --skill <name> -a claude-code -g -y` | MIT | test-reliability, selector-drift-recovery, ai-test-generation |
| conventional-changelog | full | `npx skills@1.7.0 add conventional-changelog/conventional-changelog#<commit> --skill conventional-commit-message -a claude-code -g -y` | ISC | the commit message rules that feed versioning |
| trailofbits/skills | full | `npx skills@1.7.0 add trailofbits/skills#<commit> --skill differential-review -a claude-code -g -y` | CC BY-SA 4.0 | security-focused review of a diff with blast radius and test coverage |

### Pinned packs

These come from `plugins/bearing/bin/pinned-packs.txt`: each repository is fetched at the
commit named there into `~/.cache/bearing-packs`, and only the listed
folders are copied to `~/.claude/skills/<name>` with a `.bearing-pack` file
recording the repository, commit and licence. A folder without that file is
never overwritten. Every SKILL.md was read at its commit before it was
listed; moving a commit means reading them again. The Trail of Bits text is
CC BY-SA 4.0, so it is installed and referenced, never copied into the kit.

| Pack (commit) | Skills installed | Licence | Serves |
| --- | --- | --- | --- |
| trailofbits/skills (32e34f8) | supply-chain-risk-auditor, agentic-actions-auditor, property-based-testing; insecure-defaults as a plugin (it is a command and a workflow, not a skill) | CC BY-SA 4.0 | dependency-audit, ci-pipeline, test-automation, vapt-report |
| getsentry/skills (c2f99a5) | gha-security-review | Apache-2.0 | ci-pipeline, vapt-report |
| openai/skills (49f948f) | security-threat-model only (the repository is deprecated; this folder carries its own Apache-2.0 licence) | Apache-2.0 | threat-model |
| android/skills (b1f707d) | agp-9-upgrade, navigation-3, edge-to-edge, android-intent-security, r8-analyzer, android-testing-setup (installed under that name; upstream calls it testing-setup) | Apache-2.0 | android |
| flutter/agent-plugins (e89522a) | flutter-apply-architecture-best-practices, flutter-add-widget-test, flutter-add-integration-test, flutter-setup-declarative-routing, flutter-setup-localization, flutter-fix-layout-issues, dart-run-static-analysis | BSD-3-Clause | flutter |
| twostraws/SwiftUI-Agent-Skill (be297ff) | swiftui-pro | MIT | ios |
| samber/cc-skills-golang (19a0626) | golang-code-style, -error-handling, -concurrency, -context, -testing, -security, -database, -observability, -safety, -performance (10 of its 46) | MIT | go |
| hashicorp/agent-skills (c2d65df) | terraform-style-guide, terraform-test, terraform-refactor-module (upstream refactor-module) | MPL-2.0 | infra |
| supabase/agent-skills (8331f91) | supabase-postgres-best-practices | MIT | database, db-migration |
| expo/skills (cd75214) | expo-upgrade, expo-router; not eas-update, eas-app-stores or expo-dev-client, which publish or need EAS cloud builds | MIT | react-native |
| grafana/skills (1ccacf2) | k6 | Apache-2.0 | load-test |
| AccessLint/skills (2e9d733) | the accesslint plugin: accessibility-scan, -inspect, -audit, -fix, -diff, with its MCP server | MIT (plugin.json; the repository has no licence file) | accessibility |

The repository settings template denies the deploy and publish commands
these packs know about: `eas submit`, `eas update`, `eas deploy`, `npx
eas-cli`, `supabase db push`, `supabase functions deploy`, `k6 cloud` and
`terraform apply`.

`plugins/bearing/bin/brg-install-packs` installs the "full" rows; `install.sh --profile
full` calls it. Rerun either at any time; both are idempotent. Every
version and commit above comes from `plugins/bearing/bin/pinned-packs.txt`
(`<commit>` is the full commit on the pack's `cli` row); the official
marketplace takes no version pin. `npx skills@1.7.0 list -g` shows what the
skills CLI manages, `npx skills@1.7.0 update` refreshes it at the ref each
pack was installed from, `npx skills@1.7.0 remove <name> -g` drops one.

## Other packs, not installed

Skills and references point to these for jobs outside the workflow's
steps. The installer does not fetch them.

| Pack | Install | Licence | What it does |
| --- | --- | --- | --- |
| plugin87/ux-ui-agent-skills | `claude plugin marketplace add plugin87/ux-ui-agent-skills` then install | MIT | a design-system-to-code pipeline (DTCG tokens, brandkit, design-review, a11y-audit) |
| bitjaru/styleseed | `claude plugin marketplace add bitjaru/styleseed` then `claude plugin install styleseed@styleseed` | MIT | flows and screen builds with a persistent project style |
| superdesign (official marketplace) | `claude plugin install superdesign@claude-plugins-official` | MIT | a variant canvas backed by a hosted service |
| greensock/gsap-skills | `npx skills add greensock/gsap-skills -a claude-code -g -y` | MIT | GSAP animation, for projects on GSAP |
| affaan-m/ECC motion skills | `npx skills add affaan-m/ECC --skill motion-foundations --skill motion-patterns -a claude-code -g -y` | MIT | Framer Motion tokens and patterns for React; the full pack is 292 skills, this installs two |
| LambdaTest agent-skills | copy `<skill>/` from the repository into `~/.claude/skills` | MIT | Appium, Detox, Espresso and XCUITest skills |
| wshobson/agents | `claude plugin marketplace add wshobson/agents` | MIT | stride-analysis-patterns, openapi-spec-generation, incident-runbook-templates, postmortem-writing, changelog-automation, llm-application-dev |
| langfuse, deepeval, mlflow, agent-sdk-dev, growthbook, context7 (official marketplace) | `claude plugin install <name>@claude-plugins-official` | various | GenAI and platform tools for those vendors; install when the vendor is in use |
| huggingface-skills (Hugging Face, official marketplace) | `claude plugin install huggingface-skills@claude-plugins-official` | Apache-2.0 | huggingface-llm-trainer and trl-training run a training job that llm-fine-tuning plans (HF Jobs needs a paid plan); huggingface-vision-trainer trains detectors and classifiers; huggingface-community-evals gives public benchmark scores; 26 skills |
| fiftyone (Voxel51, official marketplace) | `claude plugin install fiftyone@claude-plugins-official` | Apache-2.0 | fiftyone-model-evaluation and fiftyone-dataset-curation for error analysis, duplicates and curation; needs the FiftyOne app and its MCP server |
| twilio-developer-kit (Twilio, official marketplace) | `claude plugin install twilio-developer-kit@claude-plugins-official` | MIT | twilio-voice-conversation-relay for the phone leg of a voice agent on Twilio |
| pr-review-toolkit, code-simplifier, security-guidance (official) | `claude plugin install <name>@claude-plugins-official` | Apache-2.0 | review agents; security-guidance adds hooks to every session |
| deanpeters/Product-Manager-Skills | not installed | CC BY-NC-SA 4.0 | product-management skills under a non-commercial licence |

## Kept off work repositories

Denied in the repository settings template: gstack `setup-browser-cookies`
(imports your browser cookies into the agent), `codex` and
`benchmark-models` (send code to other model providers), `pair-agent`,
`land-and-deploy` and `setup-deploy` (deploy from the agent); GSD Core
`gsd-ship` (creates a PR) and `gsd-review`, `gsd-plan-review-convergence`
(send plans to external AI CLIs). gstack `/ship` stops at the push the
permissions refuse; use `merge-request`.

## How the design lane uses other packs

- `/design-consultation` (gstack) writes the design direction and a
  `DESIGN.md` the Bearing design skills read.
- `design-directions` makes the variants as local HTML.
  gstack `design-shotgun` calls OpenAI's image API and needs
  `~/.gstack/openai.json`.
- `design-critique` reviews prototypes; once the app runs in a browser
  the workflow calls gstack `/design-review`, which needs the browse
  daemon.
- ui-craft `clarify` reviews UX copy (buttons, errors, empty states, form
  hints); `prose-lint` covers documents, MR text and commits.

## Keeping them current

`upgrade-tools` updates every installed source in one run: each
marketplace plugin (`claude plugin update <name>@<marketplace>`), gstack
(through `/gstack-upgrade`), the skills-CLI packs (`npx skills@1.7.0
update`) and GSD Core (through `/gsd-update`), with versions before and
after and a count. The installers fetch what `pinned-packs.txt` pins; an
upgrade moves gstack and GSD Core past their pins on request, and a new
pin for everyone is a new row value in that file, tested at each Bearing
release (noted in CHANGELOG.md). When a pack renames a skill, `bin/gen-guide.py` fails
until `docs/known-skills.txt` is regenerated (`--write-known-skills`) and
the workflow tables are corrected.
