# Test scenarios

<!-- Template guidance: one block per backlog story naming every path a test
     must cover (happy, alternate, error, edge, and security, performance
     and accessibility where the story touches them), each pointing at the
     TC rows in test-cases.md. Testers and reviewers read it to see what is
     covered before reading a single case. Written by test-cases from
     the backlog; change the backlog, not this file. Delete each comment
     when you fill its section. -->

Source: `<backlog path>` as of <YYYY-MM-DD>. One block per story. Written by
`test-cases`; change the backlog, not this file, to change a scenario.
Each row names the cases in `test-cases.md` that cover it.

## US-nn-nnn: <story title>

<!-- What: the story's requirement links (or n/a), its ACs, one row per
     scenario, grouped by category, then the categories left out and the
     story's invariants: what must hold whatever the path.
     Good: each scenario has a permanent id TS-<story>-k and a "Proves
     that" sentence naming the outcome a stakeholder cares about, not the
     steps; happy, alternate, error and edge rows always exist; security,
     performance and accessibility rows appear when the story touches auth,
     PII, external input, a list, a screen or an SLO, and a category left
     out is named on the Not applicable line with its reason; every row
     names the TC ids that cover it; each invariant is also a case of its
     own in test-cases.md. The test plan copies these rows.
     Example: | TS-US-01-001-4 | Edge | A 255-character email, one past the
     limit, gets 422 | an over-long address is refused before any lookup |
     AC-US-01-001-1 | TC-0004 |, and the invariant "a user sees only their
     own sessions (TC-0011)". -->

Requirements: REQ-nnn, REQ-nnn
Acceptance criteria: AC-US-nn-nnn-1, AC-US-nn-nnn-2

| Scenario | Category | What happens | Proves that | ACs | Cases |
| --- | --- | --- | --- | --- | --- |
| TS-US-nn-nnn-1 | Happy | <the main path in one sentence> | <the outcome it proves> | AC-US-nn-nnn-1 | TC-0001 |
| TS-US-nn-nnn-2 | Alternate | <a second valid route to the same outcome> | <the outcome it proves> | AC-US-nn-nnn-1 | TC-0002 |
| TS-US-nn-nnn-3 | Error | <what the user sees when input or a dependency fails> | <the outcome it proves> | AC-US-nn-nnn-2 | TC-0003 |
| TS-US-nn-nnn-4 | Edge | <empty, maximum, zero, one past the limit, concurrent> | <the outcome it proves> | AC-US-nn-nnn-2 | TC-0004, TC-0005 |
| TS-US-nn-nnn-5 | Security | <wrong user, expired token, injected input> | <the outcome it proves> | AC-US-nn-nnn-1 | TC-0006 |
| TS-US-nn-nnn-6 | Performance | <the SLO this story must hold under load> | <the outcome it proves> | AC-US-nn-nnn-2 | TC-0007 |
| TS-US-nn-nnn-7 | Accessibility | <keyboard-only, screen reader, contrast> | <the outcome it proves> | AC-US-nn-nnn-1 | TC-0008 |

Not applicable: <category: reason; category: reason, or none>
Invariants: <what must always hold (TC ids), or none>

## Needs rewording

<!-- What: acceptance criteria with no testable expected result, each one
     counted as uncovered until the backlog is fixed.
     Good: the AC id, its exact wording in quotes and why nothing can be
     asserted; never an expected result invented to make it testable.
     Example: - AC-US-02-004-3: "export works correctly" (no format, size or
     destination is named) -->

Criteria with no testable expected result. Each one counts as uncovered
until the backlog is fixed.

- AC-US-nn-nnn-k: "<the wording>" (why it cannot be tested)
