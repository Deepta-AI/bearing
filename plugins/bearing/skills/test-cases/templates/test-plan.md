# Test plan: <product or release>

<!-- Template guidance: docs/testing/test-plan.md, the one document QA,
     the lead and the client read to know what will be tested, how, where,
     and what is still unclear. test-cases writes it last, after the
     gate passes, from risks.md, test-scenarios.md and test-cases.md; it
     never introduces a case or a count of its own. cases_check.py --plan
     checks it: the counts lines are quoted verbatim, every story has a
     scenario, every live case sits in one, every concern is tagged. Keep
     the Scenario table's header row: a table-to-CSV exporter reads it.
     Every comment says what goes there (What), what a strong entry has
     (Good) and an example (Example). Delete each comment when you fill
     its section. -->

Backlog: `<backlog path>` as of <YYYY-MM-DD>   Cases: docs/testing/test-cases.md
Version: v<n>   Author: <name or "unattributed">

## 1. Headline

<!-- What: the size of the plan in three lines: scenarios, then the gate's
     two counts lines exactly as it printed them.
     Good: nothing here is typed by hand except the scenario count, which
     the gate checks against the table below; a sentence such as "every
     criterion has a case" appears only when the quoted line shows every
     AC with cases, and it is better left to the quoted line.
     Example: "Scenarios: 41" then "test-cases: 58 ACs, 58 with cases, 163
     live cases, ..." then "test-types: unit 44, integration 61, e2e 49,
     manual 9; by machine 154 (automated 0, planned 154), by hand 9" -->

Scenarios: S
<the cases_check "test-cases:" line, verbatim>
<the cases_check "test-types:" line, verbatim>

## 2. Risk summary

<!-- What: the risks that set the depth of testing, highest first, from
     risks.md.
     Good: every High risk is listed with its story and the cases that
     prove it cannot happen; Medium and Low are summarised by count; the
     levels match the register, never re-rated here.
     Example: "R-004 | US-01-004 | A member reads another tenant's invoice by
     changing the id | High | TC-0031, TC-0032, TC-0033" -->

| Risk | Story | What could go wrong | Level | Cases |
| --- | --- | --- | --- | --- |
| R-nnn | US-nn-nnn | <failure a user or the business would notice> | High | TC-nnnn |

Medium: <count, story ids>   Low: <count>

## 3. Scenarios

<!-- What: every scenario from test-scenarios.md, one row each, grouped by
     story in backlog order: what it proves and the cases that prove it.
     Good: "Proves that" states the outcome a stakeholder cares about in
     one sentence ("a locked account cannot sign in by any route"), never
     the steps; every story in scope has a row; every live case appears in
     one row's Cases; Run by says machine, hand or both, from the cases.
     Example: "TS-US-01-001-2 | US-01-001 | Lockout after five failures |
     a guessed password stops working after five tries, on every route |
     TC-0005, TC-0006, TC-0007 | machine" -->

| Scenario | Story | Title | Proves that | Cases | Run by |
| --- | --- | --- | --- | --- | --- |
| TS-US-nn-nnn-1 | US-nn-nnn | <short title> | <the outcome it proves> | TC-nnnn | machine / hand / both |

## 4. Entry criteria

<!-- What: what must be true before test execution starts.
     Good: each is checkable by someone other than the author (a build id
     deployed, seed data loaded, accounts created), and names who confirms
     it.
     Example: "- The release candidate build is deployed to staging and its
     health check returns 200 (release manager)." -->

- <condition, and who confirms it>

## 5. Exit criteria

<!-- What: what must be true to call testing done for this release.
     Good: measurable against the case table: P1 cases passed, no open
     defect above a stated severity, the gate at 0 problems; a waiver names
     who can grant it.
     Example: "- Every P1 case passes on every browser in section 6; no open
     defect of severity 1 or 2." -->

- <measurable condition>

## 6. Environments

<!-- What: where the cases run: environments, browsers and devices, and the
     data each needs.
     Good: the browser matrix is the suite's own (chromium, firefox, webkit,
     a mobile Chrome and a mobile Safari device, as the Playwright projects
     name them); device and OS versions are stated; a case that needs a
     physical device or a clock control says so.
     Example: "staging | chromium, firefox, webkit, Pixel 7 (mobile-chrome),
     iPhone 15 (mobile-safari) | seed: 3 tenants, 20 users | clock control
     for expiry cases" -->

| Environment | Browsers and devices | Data and controls |
| --- | --- | --- |
| <name> | chromium, firefox, webkit, Pixel 7 (mobile-chrome), iPhone 15 (mobile-safari) | <seed data, flags, clock control> |

## 7. What QA raised while writing this

<!-- What: every concern met while deriving cases that a person must
     answer, one bullet each, tagged.
     Good: the tag is one of [assumption] (a reading was chosen), [untestable]
     (no observable outcome), [undefined] (a value or wording is missing),
     [contradiction] (two sources disagree) or [risk] (testable but
     dangerous); each names the AC or story and what the cases do meanwhile;
     none of these is also claimed as covered elsewhere in the plan.
     Example: "- [undefined] AC-US-01-001-2 gives no lockout message text;
     TC-0005 asserts that a role=alert appears, not its wording." -->

- [assumption | untestable | undefined | contradiction | risk] <concern, the AC or story, what the cases do meanwhile>
