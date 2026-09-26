# Model card: <name>

<!-- Template guidance: every section below carries a comment saying what goes
     there (What), what a strong entry has (Good) and a one-line example
     (Example). Delete each comment when you fill its section. The card
     describes one trained open model for whoever serves, audits or retires
     it. Every section is filled: "not evaluated" is an allowed answer,
     blank is not. -->

Status: proposed | training | evaluated | serving | retired
Owner: <person>. Task: <PREFIX>-<n>. ADR: docs/adr/NNNN-<title>.md

## Purpose

<!-- What: one paragraph: what the model does, for which feature, and the
     prompt or API path it replaces; the target metric and the number to
     beat from docs/genai/evals.md.
     Good: the number to beat is a measured baseline (marked "minimal" if it
     came from the ten-case run); training without one is not allowed.
     Example: "Classifies inbound support emails into 14 queues, replacing
     the claude-sonnet-5 prompt path; target accuracy 0.93, baseline 0.91
     at a cost the volume cannot carry." -->

## Base model and recipe

<!-- What: the exact base checkpoint and its licence, the recipe, the
     teacher for distillation, the toolchain, the run directory, the
     hyperparameters and the compute used.
     Good: an exact checkpoint id, not a family name; the licence's use
     restrictions are named; hyperparameters are the values used, not the
     field names; compute is GPU type, count and hours.
     Example: "Hyperparameters | r 16, alpha 32, lr 2e-4, epochs 3, batch
     16, max length 2,048" -->

| Field | Value |
| --- | --- |
| Base checkpoint | <family, size, exact id> |
| Licence of the base | <licence and any use restriction> |
| Recipe | LoRA SFT | DPO | distillation | continued pretraining |
| Teacher (distillation) | <claude-opus-5 | claude-sonnet-5 | none> |
| Toolchain | TRL + PEFT <version> | Axolotl <version> |
| Run directory | runs/<name>/<date>/ |
| Hyperparameters | r, alpha, lr, epochs, batch, max length |
| Compute used | <GPU type> x <count>, <hours> |

## Data

<!-- What: the counts at every stage, the sources and their proportions,
     the labelling guide, the PII removal function and the licence or
     consent covering each source.
     Good: counts shrink stage by stage and add up; dedup is exact then
     near (MinHash at 0.85) and by document across splits, so the test
     split cannot leak; the test split is the llm-eval golden set.
     Example: "After dedup (exact, near) | 4,212 (exact 180 removed, near
     96 removed)" -->

| Stage | Count |
| --- | --- |
| Collected | <N> |
| After PII removal | <N> |
| After dedup (exact, near) | <N> |
| Train / validation / test | <a> / <b> / <c> |

Sources with proportions (user logs with consent, owner-written,
teacher-generated, synthetic). Labelling guide:
`docs/genai/labelling-<name>.md`. PII removal function and its test.
Licence or consent that covers training on each source.

## Evaluation

<!-- What: the same eval run on the test split for the prompt-only
     baseline, the base model and this checkpoint, with score, p95 latency
     and cost; then the noise floor, regressed tags and the cases lost.
     Good: the checkpoint beats the prompt-only path by more than the noise
     floor or it does not ship; a format gain that hurts accuracy still
     fails, so both metrics are reported.
     Example: "This checkpoint | 0.94 | 0.4 s | $0.31" -->

| Path | Score (<metric>) | p95 latency | Cost per 1K requests |
| --- | --- | --- | --- |
| Prompt-only baseline (<model>) | | | |
| Base model, same prompt | | | |
| This checkpoint | | | |

Noise floor from two baseline runs: <x.xx>. Per-tag scores where a tag
regressed. Cases the model fails that the baseline passes, with a
sentence each.

## Intended use and limits

<!-- What: the inputs it was trained on, what happens outside them, the
     known failure modes and what it must not be used for.
     Good: limits are measured (language, length, domain) and failure modes
     come from the eval misses, not general caveats.
     Example: "Trained on English emails under 1,500 tokens; Hindi and
     longer emails fall back to the prompt route." -->

- Inputs it was trained on (language, length, domain) and what happens
  outside them.
- Known failure modes from the eval misses.
- What it must not be used for.

## Safety and privacy

<!-- What: how PII was kept out of training data and how that was checked,
     whether injection and refusal behaviour was evaluated, which bias
     checks ran.
     Good: the PII line names the function and the test or audit; "not
     evaluated" and "none" are honest answers, a blank is not.
     Example: "PII in training data: removed by scrub_pii() in
     data/prep.py, verified by tests/test_scrub.py and a 200-row sample
     audit." -->

- PII in training data: removed by <function>, verified by <test or
  sample audit>.
- Injection and refusal behaviour: <evaluated | not evaluated>.
- Bias checks run: <which | none>.

## Serving

<!-- What: the route in llm/routing.yaml with its canary percentage, the
     fallback and rollback, and what is monitored.
     Good: the canary starts at 5 percent; rollback is a route change, not
     a deploy; a distilled model keeps the teacher route as its fallback.
     Example: "Route in llm/routing.yaml: email-triage-small, canary 5
     percent; fallback email-triage (claude-sonnet-5)." -->

- Route in `llm/routing.yaml`: <name>, canary <p> percent.
- Fallback: <route>. Rollback: change the route, no deploy.
- Monitoring: eval score on sampled traffic, error rate, p95 latency,
  through the gateway metrics.

## Changelog

<!-- What: one row per version of the model.
     Good: each row has the date, a version the run directory can be
     found by, what changed and the eval score on the same test split.
     Example: "2026-10-02 | v2 | added 800 owner-written refund emails |
     0.94" -->

| Date | Version | Change | Score |
| --- | --- | --- | --- |
