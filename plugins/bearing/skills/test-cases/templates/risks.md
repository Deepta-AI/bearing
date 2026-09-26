# Test risks

<!-- Template guidance: the risk register that decides how deep each story
     is tested before any case is written. test-cases writes it from the
     backlog, the threat models and the repository's history; cases_check.py
     parses the table, so keep the header row and its column names. Testers
     and reviewers read it to see why one story has twelve cases and another
     has two. Delete each comment when you fill its section. -->

Source: `<backlog path>` as of <YYYY-MM-DD>; threat models: `<paths>` or none.
Ids are permanent; a risk that no longer applies keeps its row with level
`Low` and "closed: <reason>" in the risk text.

## How the level is set

<!-- What: the scale this register uses; keep it as written so every
     register reads the same.
     Good: a reader can recompute any row's level from its likelihood and
     impact without asking anyone.
     Example: M likelihood and H impact is High. -->

Likelihood (L, M, H) is how probable the failure is, from the evidence named
in the row: the size of the change, branching or concurrency in it, a new
integration or dependency, defects in the same files (`git log --grep=fix`
over the paths), and how settled the requirement is.
Impact (L, M, H) is what it costs when it happens: H for money, auth, data
loss, PII or a legal duty; M for a core flow; L for cosmetics.

| Likelihood / Impact | L | M | H |
| --- | --- | --- | --- |
| L | Low | Low | Medium |
| M | Low | Medium | High |
| H | Medium | High | High |

Depth by level, counted in live cases: High needs three, one with a `not:`
oracle and one of type integration or e2e; Medium needs two, one with a
`not:` oracle; Low needs one.

## Register

<!-- What: one row per risk; every story in scope has at least one, and
     every threat (T-nn) in the threat models is the Source of one.
     Good: the risk names a failure a user or the business would notice
     ("a member reads another tenant's invoice"), never a component ("the
     invoice service"); the Source says where the risk came from (an AC id,
     a T-nn, a past defect's commit, "change size"); the Cases cell lists
     the TC ids that prove it cannot happen.
     Example: see R-001 below; replace it with this backlog's rows. -->

| Risk | Story | What could go wrong | Source | Likelihood | Impact | Level | Cases |
| --- | --- | --- | --- | --- | --- | --- | --- |

<!-- Example row, to show the shape; delete this comment and add real rows
     to the table above:
       | R-001 | US-01-004 | A member reads another tenant's invoice by changing the id in the URL | T-02, AC-US-01-004-2 | M | H | High | TC-0031, TC-0032, TC-0033 |
       | R-002 | US-01-001 | A locked account can still sign in through the remember-me cookie | AC-US-01-001-2, fix 3f2a91c | M | M | Medium | TC-0005, TC-0006 |
       | R-003 | US-02-003 | The export button label wraps on a phone | change size | L | L | Low | TC-0040 |
-->
