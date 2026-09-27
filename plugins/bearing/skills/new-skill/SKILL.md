---
name: new-skill
description: 'Creates a new skill for this plugin in its git checkout with the house sections and lints, then evals it against a baseline. Use when asked to "add a skill", "make this a skill" or "turn this checklist into a skill".'
argument-hint: "<name> [one-line purpose]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(claude plugin validate:*), Bash(ls:*), Bash(make:*), Bash(mkdir -p .scratch/skill-evals:*)
---

# new-skill

One skill does one job. The description is what makes it trigger; write it
first, then the steps, then the gotchas (the most valuable part).

This skill is the house-format pass plus the judgement a new skill needs:
whether it should exist, what its source material gets wrong, and whether
a check it ships can be trusted. Whether the skill actually helps is
measured by Anthropic's `skill-creator`, which runs each case with the
skill and against a baseline without it. Neither replaces the other.

## Inputs

- A checkout of the kit: the current directory when it holds
  `.claude-plugin/marketplace.json` with name `bearing` and
  `plugins/bearing/`; if not, one question:
  "where is your Bearing checkout?" (the installed plugin copy under
  `~/.claude/plugins` is read-only and does not count). No path: stop with
  "provide the path to a Bearing git checkout".
- The kit's own rules: `CONTRIBUTING.md`, `CLAUDE.md` and `docs/adr/` in
  the checkout, read before writing anything. Where they differ from this
  skill, they win.
- The `Makefile`: the gate targets this checkout defines. A target named
  below that it lacks is reported as missing, never invented.
- Name: `$1`; if absent, asked in the interview.
- Purpose and triggers: `$2`, the request, any document it points to (a
  checklist, a runbook) and the interview below.
- Template: `templates/SKILL.template.md` in this skill's folder.
- Registry files: `docs/SKILLS.md` and `CHANGELOG.md`; if either is
  missing, the row or line is printed for the author to place.
- Plugin: `plugins/bearing` for a stack-neutral workflow skill;
  `plugins/bearing-backend` or `plugins/bearing-apps` for a skill about
  one language, framework or platform. Written below as `<plugin>`.
- Sibling skills and scripts: `plugins/*/skills/*/SKILL.md` and
  `plugins/*/bin/`; the precedent for shape, and something to audit.
- Evals: the `skill-creator` skill; if it is not installed or not
  allowed, the cases are still written to `evals/<name>/evals.json` in its
  schema and the report says "evals written, not run".

## Steps

1. Resolve the checkout; every path below is relative to it. Run
   `make check` once before changing anything, so a failure you did not
   cause is known and not blamed on the new skill.
2. Should it exist, and on what? Before naming anything:
   - grep every skill's description and body for the job; if one already
     does it, propose extending that one instead;
   - verify everything the request refers to ("same idea as the node
     one", "like the release skill"). If it does not exist, say so in the
     report, name what you model on instead, and never cite or copy a
     thing that is not there;
   - audit the precedent you will copy against the kit's rules (a check
     that passes on empty input, a grant wider than it needs). Do not copy
     the defect; report it under Noticed. Fixing it is a separate change
     with its own test, done only if asked.
3. Name: lowercase words joined by hyphens, at most 64 characters
   (`^[a-z0-9]+(-[a-z0-9]+)*$`), saying what the skill does, no folder of
   that name in any plugin. Refuse a name that spans two jobs.
4. If the source is an existing document (a team checklist, a runbook),
   decide each of its steps: keep, generalise, change, reorder or drop.
   What a generalist misses:
   - Team facts are more than names. Hosts, channels, ticket prefixes and
     team names, and also policy values (severity thresholds, approvers,
     SLAs, time windows). The skill reads each from the adopting
     repository (its `CLAUDE.md` or `.bearing/company.json`) and says what
     it does when absent: ask once, or omit the step. Never bake one
     team's value in as the default. Reuse the keys the kit already
     documents for that file; a key you must add is documented beside
     them in the same change.
   - A step that publishes (push, tag, merge, deploy, post) becomes a
     printed command for the developer (the kit's no-publish ADR), and
     `allowed-tools` grants none of them.
   - A step that skips a gate (`[skip tests]`, `--no-verify`, "if the fix
     is small") is dropped, not softened.
   - Order: nothing is tagged or announced before the checks pass on the
     exact commit being released; the printed block says "after CI is
     green on <sha>", not just the command.
   - Side effects: "merge the hotfix branch back into main" carries the
     version bump and branch-only edits into main; bring the fix commit
     instead (`cherry-pick -x`, or a follow-up change). A step that
     assumes a file every repository may not have (a `VERSION` file)
     takes the value where the sibling skills do (tags, for release
     numbers), with the file as the optional case.
   - Keep the guarantee a step exists for (the fix reaches main) even
     when you change its mechanism.
   Decide what happens to the source document (left as is, or replaced
   by a pointer to the skill) and say which.
5. Interview briefly, one question at a time, until you can fill: what
   it does in one sentence; three or more phrases a developer would say;
   whether Claude may load it on its own (almost always yes); inputs,
   where each is looked for first and its fallback; outputs; tools (least
   privilege); the two or three ways it goes wrong. With nobody to ask,
   pick the recommended option and record the question and the choice.
6. Write `<plugin>/skills/<name>/SKILL.md` from the template. Description:
   what it does, naming the deliverable, then "Use when" with two to four
   quoted phrases, most common first; 220 characters at most. Sections in
   order: title, purpose paragraph, optional `Not this:` line naming the
   neighbour, Inputs (each with its fallback; never a prerequisite on
   another skill), Steps, Output contract (a fenced block with counts),
   Gotchas. `argument-hint` when it takes arguments. Under 140 lines. No
   em dashes, no company name, no tracker default. A skill in another
   plugin is named with its prefix (`bearing-backend:go`, `bearing:<name>`);
   a path into another plugin goes through `bin/brg-kit-paths --skill
   <name>` where the kit has it. Files the skill reads go in
   `references/`, files it copies in `templates/`, beside its SKILL.md.
   Every file, script, target or template the skill names exists or is
   added in this change.
7. If the skill ships a check (a script that passes or fails something),
   that is the part most likely to be wrong while its tests pass:
   - it lives in `<plugin>/bin/`, runs as
     `${CLAUDE_PLUGIN_ROOT}/bin/<script>`, and `allowed-tools` grants that
     script by name (never an interpreter wildcard such as python3 or
     bash, and never bare Bash);
   - its unittest under `tests/` covers at least: a violation reported
     with file, line and what failed, exiting non-zero; the kit's own
     prescribed pattern passing (read the sibling convention skill and
     test exactly the form it tells people to write); a lookalike that
     must still fail (a dependency that is not auth, a comment that
     mentions the keyword); zero items failing with the count printed;
     an allowlist entry honoured;
   - defaults are narrow and exact (the one name the convention uses),
     extended by a file in the adopting repository, never a prefix or
     substring pattern that accepts something that never rejects;
   - what it reports and what an allowlist holds use the same normalised
     form (for routes, the full path after every router and include
     prefix), and an allowlist entry that matched nothing is reported;
   - what it cannot resolve (an import it cannot follow, a dynamic path)
     is counted and printed, not silently passed.
   Wiring the check into an existing skill (so `python` runs it the way
   `go` runs its own) changes that skill for every team: keep it
   additive and name it in the report, or print it as a follow-up.
8. Validate: `make validate` (or `claude plugin validate --strict` on the
   marketplace and each plugin) and each lint target the Makefile has.
9. Evals, through skill-creator (Skill tool): skill path
   `<plugin>/skills/<name>`; two or three realistic prompts in
   `evals/<name>/evals.json` (outside the skill folder), each with
   expectations about this skill's own trap (the publish commands printed
   and not run, the house pattern passing, empty input failing), not
   generic ones any skill would pass; workspace under
   `.scratch/skill-evals/<name>/`. Run with and without the skill, grade,
   benchmark; for an auto skill, run the description optimiser with near
   misses from neighbouring skills and keep the result within 220
   characters. A skill that does not beat the baseline is not added.
   Never add the skill to `evals/.pending`: that list only shrinks.
10. Trigger cases in `evals/triggers.json`: three requests (terse, with
    context, problem only) and two near misses owned by a neighbour, none
    copying a quoted description phrase. `make trigger-eval ONLY=<name>`
    where the target exists.
11. Registry: `make docs` regenerates the table in `docs/SKILLS.md`
    (never hand-edit it); place the skill in `bin/gen-guide.py` where
    that file exists; a line under Unreleased in `CHANGELOG.md`. Then
    `make check` passes.
12. Commit nothing; leave the change in the working tree, print the
    commit command, and report as below.

## Output contract

```
## New skill: <name>
Checkout: <path>
Files: <plugin>/skills/<name>/SKILL.md [, bin/<script>, tests/<test>, ...]
Source steps: <n> kept, <n> generalised, <n> changed, <n> dropped (each with why) | no source document
Validate: <tail>   make check: passed | failed (<target>, pre-existing | ours)
Evals: N cases; with skill P/E, baseline B/E | written, not run
Triggers: loaded on S/3, false triggers F/2 | written, not run
Not run: <each skipped step: benchmark, trigger eval, description optimiser>
Noticed: <missing referents, defects in precedents>
Try: "<trigger phrase>"
```

## Gotchas

- A description that only says what the skill does will not trigger; it
  must also say when. Too many triggers fire on everything.
- "Same as the X one" is a claim about the kit. Check it; a skill built
  on a thing that does not exist inherits a false first line.
- The precedent is not the standard. Copy its shape, not its defects;
  the kit's CONTRIBUTING and ADRs are the standard.
- A check tested only on the author's own fixture passes the author's
  assumptions. Test the house pattern and a lookalike too.
- Every check fails on empty input and prints the count it examined.
- A report that says "evals written" as if they ran, or leaves a skipped
  step unmentioned, is the most common false claim here. Name each step
  not run.
- A skill that stops because another skill has not run is broken. Every
  input needs a fallback.
