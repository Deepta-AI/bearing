---
name: new-skill
description: 'Creates a new skill for this plugin in its git checkout with the house sections and lints, then evals it against a baseline. Use when asked to "add a skill", "make this a skill" or "turn this checklist into a skill".'
argument-hint: "<name> [one-line purpose]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(claude plugin validate:*), Bash(ls:*), Bash(make:*), Bash(mkdir -p .scratch/skill-evals:*)
---

# new-skill

One skill does one job. The description is what makes it trigger; write it
first, then the steps, then the gotchas (the most valuable part).

This skill is the house-format pass: naming, sections, the independence
contract, least-privilege tools, the lints and the registry. Whether the
skill actually helps is measured by Anthropic's `skill-creator`, which
runs each case with the skill and against a baseline without it, grades
the outputs and, for a skill Claude may trigger, tunes the description.
Neither replaces the other.

## Inputs

- A checkout of the kit: the current directory when it holds
  `.claude-plugin/plugin.json` with name `bearing`; if not, one question:
  "where is your Bearing checkout?" (the installed plugin copy under
  `~/.claude/plugins` is read-only and does not count). No path: stop with
  "provide the path to a Bearing git checkout".
- Name: `$1`; if absent, asked in the interview.
- Purpose and triggers: `$2` and the interview below; nothing else is
  needed from any repository.
- Template: `templates/SKILL.template.md` in this skill's folder.
- Registry files in the kit: `docs/SKILLS.md` and `CHANGELOG.md`; if
  either is missing, the row or line is printed for the author to place.
- Sibling skills for conventions: `skills/*/SKILL.md` in the checkout;
  read two as examples when the interview stalls on shape.
- Evals: the `skill-creator` skill (Anthropic's example-skills or
  document-skills plugin); if it is not installed, the cases are still
  written to `evals/<name>/evals.json` at the kit root in its schema, and the report says "evals
  written, not run (install skill-creator)".

## Steps

1. Resolve the checkout as in Inputs; every path below is relative to it.
2. Name: `<name>`, lowercase words joined by hyphens, no prefix, at most
   64 characters (`^[a-z0-9]+(-[a-z0-9]+)*$`), saying what the skill does.
   Refuse a name that spans two jobs ("review-and-fix"). Check
   `skills/<name>/` does not exist.
3. Interview briefly, one question at a time, until you can fill:
   - what the skill does, in one sentence;
   - the phrases a developer would say when they need it (three or more);
   - whether it is safe for Claude to load on its own (almost always yes;
     `disable-model-invocation: true` hides the skill from Claude
     entirely, so it never triggers from what the user says);
   - inputs, where each is looked for first and its fallback, outputs,
     and the tools it needs (least privilege);
   - the two or three ways it goes wrong (gotchas).
4. Write `skills/<name>/SKILL.md` from `templates/SKILL.template.md` in
   this skill's folder. Description = what it does, naming the
   deliverable, then "Use when" with two to four quoted phrases a user
   types, most common first; 220 characters at most. The start of a
   description is what survives when Claude Code shortens the listing. Sections in
   this order and with these headings: title, one-paragraph purpose, an
   optional `Not this:` line naming the neighbour it is not, Inputs
   (each input, where it looks first, the fallback when absent; never a
   prerequisite on another skill), Steps, Output contract (a fenced
   block with counts), Gotchas. A skill that takes arguments carries an
   `argument-hint`.
   `allowed-tools` names the kit scripts it runs as
   `Bash(bash *bin/<script> *)`, never a bare `bash` wildcard. Under
   140 lines. No em dashes, no company name, no tracker default.
5. If the skill needs files, add `references/` (things to read) or
   `templates/` (things to copy). Reference them by relative path; a
   template the skill fills must live in its own folder, not only under
   `templates/repo/`.
6. Validate the house format: `claude plugin validate --strict .` from
   the checkout root, then `make lint-skills lint-tools`. Both must pass.
7. Evals, through skill-creator (Skill tool), with this brief: skill path
   `skills/<name>`; two or three realistic prompts saved to
   `evals/<name>/evals.json` (outside the skill folder, so a run that follows the skill never reads its grading) in skill-creator's schema, each
   with `expectations` a grader can check (a file written, a count
   printed, a refusal on empty input); the workspace under
   `.scratch/skill-evals/<name>/`, never beside the skill; run each
   case with the skill and without it, grade, and benchmark. For an auto
   skill (no `disable-model-invocation`), also run its description
   optimiser with near-miss negatives drawn from the neighbouring skills
   (gstack, Superpowers, GSD, the other Bearing skills), and keep the
   result within 220 characters with "Use when" and at least two quoted
   phrases, or `make lint-skills` rejects it. Iterate on the skill until
   the with-skill runs beat the baseline on the expectations; a skill that
   does not beat the baseline is not added.
8. `make check`, which now includes `lint-evals`: the new skill fails
   without `evals/<name>/evals.json`.
9. Add the row to `docs/SKILLS.md` (name, one line, trigger phrase, auto or
   command) and a line to `CHANGELOG.md` under Unreleased.
10. Report: files written, the validate output, the benchmark (with skill
   against baseline, per expectation), the test phrase to try.

## Output contract

```
## New skill: <name>
Checkout: <path>
Files: skills/<name>/SKILL.md [, references/..., templates/...]
Validate: <claude plugin validate tail>   make check: passed | failed (<target>)
Evals: N cases in evals/<name>/evals.json; with skill P/E expectations, baseline B/E | written, not run (skill-creator absent)
Registry: docs/SKILLS.md row added, CHANGELOG.md line added | printed for the author
Try: "<trigger phrase>"
```

## Gotchas

- A description that only says what the skill does will not trigger; it
  must also say when. A description that lists too many triggers will
  trigger on everything. Three to five concrete phrases.
- Do not put repository-specific facts in a kit skill (a hostname, a
  team name, a port, a company). Those live in the repo's CLAUDE.md
  snapshot or in `.bearing/company.json`.
- A skill that does not beat the no-skill baseline on its own cases is
  prose Claude already follows. Cut it or find what it adds.
- Every check a skill performs must fail on empty input and print the count
  of things it checked.
- A skill that stops because another skill has not run is a broken skill.
  Every input needs a fallback: another place to look, one question, or a
  minimal inline version.
