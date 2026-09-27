---
name: test-cases
description: 'Writes manual test cases and a test plan from acceptance criteria: risk per story, scenarios, TC-numbered steps; no test code. Use when QA needs "the test cases", "the manual test plan" or scenarios.'
argument-hint: "[backlog path, default docs/product/backlog.md] [story id to limit, e.g. US-03-002]"
allowed-tools: Read, Write, Edit, Grep, Glob, Bash(ls:*), Bash(wc:*), Bash(grep:*), Bash(git log:*), Bash(python3 *skills/test-cases/scripts/cases_check.py*)
---

# test-cases

The backlog says what must be true. This skill first asks what is most
likely to go wrong and what it would cost, then turns every acceptance
criterion into cases a person or a machine can run, as many as that risk
demands, and refuses to finish while any criterion or risk has too few.

Not this: `test-automation` writes the tests, `test-run` runs
them and `test-heal` fixes them; this derives the cases they all
carry by TC id.

## Inputs

- Acceptance criteria: looks in `$1`, else `docs/product/backlog.md`, else
  `docs/backlog.md` or `docs/backlog/*.md`; if absent, asks one question:
  "paste the acceptance criteria or the ticket description, or say `code`
  to derive them from the routes and screens". Pasted text is numbered
  by this skill (`US-LOCAL-001`, `AC-US-LOCAL-001-k`). `code` derives one
  criterion per route, handler, screen or command found in the repository,
  numbered the same way and marked `inferred`; the fuller backlog comes
  from `backlog`. No answer and no code: stop with "provide acceptance
  criteria, a ticket, or a repository with routes or screens".
- Existing table: looks in `docs/testing/test-cases.md`; if absent,
  numbering starts at `TC-0001` and the file is created.
- Templates: `templates/risks.md`, `templates/test-scenarios.md`,
  `templates/test-cases.md`, `templates/test-case-steps.md` and
  `templates/test-plan.md` in this skill's folder; never a repository copy.
- Browser matrix: the Playwright projects in `playwright.config.*`; if
  absent, the suite's default (chromium, firefox, webkit, mobile-chrome on
  Pixel 7, mobile-safari on iPhone 15), marked `unconfirmed:` in the plan.
- Threat models: `docs/security/threat-model-*.md` from `threat-model`;
  if absent, the security risks come from the stories alone and the report
  says "0 threat models".
- Defect history: `git log --oneline --grep=fix -- <paths>` over the files a
  story touches; no git history or no paths yet: likelihood comes from the
  change and the requirement alone, said so in the row's Source.
- Existing register: `docs/testing/risks.md`; ids continue from the highest.
- Gate: `scripts/cases_check.py` in this skill, Python 3 only; it reads
  the backlog and the table, never the model's summary.
- Existing table without an Oracles column: the column is added and every
  live row gets its oracles in this run; nothing else in the row changes.

## Steps

1. Obtain the criteria as in Inputs. Collect every story with its title,
   its `REQ-nnn` links (or `n/a`) and its ACs. `$2` limits the run to one
   story. Record the source: `backlog`, `pasted`, or `inferred from code`.
2. Read `docs/testing/test-cases.md` if it exists. Note the highest
   `TC-nnnn`; new ids continue from it. Never renumber or delete an
   existing row; a retired case gets status `retired`.
3. Risk pass, before any scenario. For each story write one or more rows
   in `docs/testing/risks.md` from `templates/risks.md`: what could go
   wrong, in words a user or the business would notice; its Source (an
   AC id, a `T-nn` from a threat model, a fix commit in the same files,
   "change size", "new integration"); likelihood and impact (L, M, H) by
   the scale in the template; and the level they give. Every `T-nn` in the
   threat models becomes the Source of a risk, so every threat reaches a
   test. A story with nothing to fear still gets one Low row; the gate
   checks every story has one. The level sets the depth in step 5.
4. For each story write its scenario block from `templates/test-scenarios.md`:
   happy path, alternate paths, error paths, edge and boundary; and security,
   performance and accessibility when the story touches auth, PII, external
   input, a list, a screen or an SLO. Each scenario gets a permanent id
   `TS-<story id>-k` and a "Proves that" sentence: the outcome a
   stakeholder cares about, not the steps. Name a category left out on the
   Not applicable line with its reason; never skip one silently. Add the story's invariants:
   what must always hold whatever the path (a balance never negative, a
   user sees only their own records, one lock per account), each one a row
   of its own below.
5. For each AC derive rows into the table from `templates/test-cases.md`.
   Every AC that takes input gets at least three rows: one valid, one
   invalid (negative), one boundary (empty, maximum length, zero, one past
   the limit). Then deepen by risk: a High risk gets three live cases, one
   with a `not:` oracle and one of type integration or e2e (a permission or
   tenant risk gets the other user's and the other tenant's attempt); a
   Medium risk gets two, one with `not:`; a Low risk one. Write the TC ids
   into the risk's Cases cell. Columns: `TC-nnnn`, story id, AC ids, title, preconditions,
   steps, test data, expected result, oracles (step 7), type
   (`unit|integration|e2e|manual`), priority (`P1|P2|P3`), automation
   status (`planned|automated|manual-only`).
6. Type rule: logic with no I/O is `unit`; a repository or an API route is
   `integration`; a user-facing flow is `e2e`; a screen whose look a person
   signed off is `e2e` with the oracle `ui: matches baseline <name>.png`
   (a screenshot comparison, run by `test-automation`); only judgement
   no baseline can hold, or a physical device, is `manual`. A flow that must
   hold on every browser and phone says so in its title ("on every
   browser"); the suite runs it in the matrix. Priority `P1` when the AC or
   its risk is on the money, auth or data-loss path, or its risk is High;
   `P2` core flow; `P3` cosmetic.
7. Oracles, as a separate pass once every row exists. The scenario says
   what happens; the oracle says how a test proves it, and designing both
   at once is how a test ends up asserting whatever the code does. For
   each row write the Oracles cell as tagged checks separated by `;`:
   `ui:` what the user sees (`ui: role=alert "Email or password is
   incorrect"`), `data:` persisted state read back through the API or the
   store (`data: GET /sessions returns none`), `not:` what must not happen
   (`not: no session cookie; not: no navigation`), `effect:` an event,
   message or log line (`effect: otp_locked emitted once`), `inv:` an
   invariant from step 4. Every row gets at least one; a P1 row gets two
   categories, one of them `not:`. Business outcomes, never implementation
   details (a component's state, a private field).
8. Steps, for every live `manual` and `e2e` row: write its numbered
   steps into `docs/testing/test-case-steps.md` from
   `templates/test-case-steps.md`, one row per step (`TC-nnnn.k`), each an
   Action with the literal data and the Expected a tester sees before the
   next step; the last Expected is the row's Expected result. The Steps
   cell in the case table stays the one-line summary.
9. Write the four files under `docs/testing/` (create the directory).
   Then run the gate: `python3 "${CLAUDE_PLUGIN_ROOT}/skills/test-cases/scripts/cases_check.py" --steps docs/testing/test-case-steps.md`
   (add `--backlog <path>` for another source and `--story <id>` for a
   limited run; `--risks` and `--threats` move the register and the threat
   models). It fails on an AC with no live case, a duplicate id, a row with
   no oracle, an untagged or vague check, a P1 row without two categories
   including `not:`, a missing or empty risk register, a level that does
   not follow from its likelihood and impact, a risk with fewer live cases
   than its level needs, a story with no risk and a threat that is the
   source of no risk, a manual or e2e case with no steps and a vague step.
   Fix and rerun until it exits 0.
10. Write `docs/testing/test-plan.md` from `templates/test-plan.md`: the
    scenario count and the gate's "test-cases:" and "test-types:" lines
    verbatim; the High risks; every scenario with its Proves that, cases
    and who runs it; entry and exit criteria; the environments with the
    browser matrix; and every concern met on the way, tagged
    `[assumption]`, `[untestable]`, `[undefined]`, `[contradiction]` or
    `[risk]`. A "Needs rewording" AC is also a concern here. Never write
    "every criterion has a case"; the quoted line says what is true. Then
    rerun the gate with `--plan docs/testing/test-plan.md` added; it fails
    when the plan misquotes the counts, misses a story or a live case,
    leaves a concern untagged or claims coverage the gate did not prove.
11. Print its lines. Exit 1 is a failed run; say so and do not claim done.

## Output contract

```
## Test cases: <source: backlog path | pasted | inferred from code>
Stories read: N   ACs read: M   Threat models read: T
Risks: R (high H, medium M, low L)
Scenarios: S   Concerns raised: Q
<cases_check.py "test-types:" line, verbatim>
<cases_check.py "test-steps:" line, verbatim>
<cases_check.py "test-plan:" line, verbatim>
test-cases: <cases_check.py counts line, verbatim>
Files: docs/testing/risks.md, test-scenarios.md, test-cases.md,
       test-case-steps.md, test-plan.md
Result: pass | fail (<problems>, listed)
```

## Gotchas

- An AC written as "works correctly" has no testable expected result. Do
  not invent one. List it under "Needs rewording" with the story id and
  count it as uncovered.
- An oracle of "works" or "as expected" proves nothing; the gate rejects
  it. Name the text, the value, the event or the thing that must not
  appear.
- A risk rated by gut is noise. Name the evidence in Source: the AC, the
  threat, the fix commit, the size of the diff. Two reviewers reading the
  same Source should reach the same likelihood.
- Every risk High is the same as no ranking. When more than a third of
  the rows are High, read the impact scale again: H is money, auth, data
  loss, PII or a legal duty, nothing else.
- One row per AC is a smell. A criterion that takes input needs its
  negative and boundary rows or the run is not done.
- Steps are numbered actions a stranger could follow. "Verify the feature"
  is not a step, and "works" is not an Expected; the gate rejects both.
- A plan that says "every criterion has a case" next to a list of
  criteria with no test is the defect this plan exists to prevent. Quote
  the gate's line and let it speak.
- Test data is literal (`"a"*256`, `0`, `-1`, `2026-02-29`), never "some
  invalid input".
- When a backlog exists, the code is what the cases judge, never their
  source. Criteria inferred from code describe what the code does today;
  the table header says `inferred` so a later `backlog` run can
  replace them with what the product owner meant.
- The `TC-nnnn` id is the traceability key. `test-automation` names each
  test after it and `traceability` greps for it, so an id typo breaks
  the chain.
