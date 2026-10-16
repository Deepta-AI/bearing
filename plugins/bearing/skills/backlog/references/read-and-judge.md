# backlog: reading the PRD against the code, and judging each statement

Read when: steps 1 and 2: before any story is written.

1. Read the PRD (`$1` or `docs/product/PRD.md`) and collect every id
matching `REQ-[0-9]{3}` from the statements table, skipping rows marked
`withdrawn:`, and the `B` ids of its objectives. No PRD: take the source
under Inputs, split it into one testable statement per line, number
them `REQ-001` upward, and write them as a "Statements (inline, from
<source>)" table at the top of `docs/product/coverage.md` so every id
resolves; say the fuller PRD comes from `prd`. Read the existing
backlog, tasks and register; keep every epic, story, AC, task and
question id in whatever scheme they use; never renumber.
Then read the code, config and tests the statements land on. A PRD is
written against a system that already exists, and the traps live in
the gap between the two. For each rule a statement sets (a limit, a
threshold, a required field, who may act), find where the code holds
it and note one of: enforced as stated; held with another value (name
the constant, the test that pins it and any policy it cites); checked
nowhere below the screen (a rule the service does not refuse is not
enforced: an API call or an import skips the form); or contradicted
by a rule the code enforces that the statement breaks (a permission, a
state transition). The first is a note; the second and fourth are
Q-nnn contradictions; the third becomes a criterion that the service
itself refuses, with the file and function named. Also read any notes,
minutes or ADRs beside the PRD: a decision recorded there and not yet
in the PRD is raised, never cited under a REQ id.
2. Judge each REQ and record the judgement and one sentence of why (both
go into coverage.md):
- story: a user can do something new when it lands; it seeds a story;
- criterion-of: it qualifies another statement (a limit, a message, a
  timing); it becomes an AC of that story;
- platform-detail-of: the same capability on web, iOS, Android; one
  story, the platforms named in its AC or tasks;
- duplicate-of: same outcome as another REQ; merge, cite both ids;
- split: it hides two capabilities; two stories, both citing the REQ;
- non-functional: a quality (security, performance, accessibility)
  carried as AC by every story it constrains;
- out-of-scope: the input or a decision puts it out; it needs a Q-nnn
  whose Decision says so, cited in the Why cell.
