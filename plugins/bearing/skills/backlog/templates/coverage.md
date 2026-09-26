# Coverage: PRD statements to stories

<!-- Template guidance: proves every live PRD statement is accounted for:
     covered by an acceptance criterion, or judged out of scope with a
     recorded decision. The verdict is scripts/coverage_check.py's, which
     reads the AC Covers lines in backlog.md, never this matrix. Reviewers
     and the client read it to see what became of each statement; write
     the file even when gaps exist so they show. The matrix is the one
     table a table-to-CSV exporter reads; keep its header row. Every comment
     says what goes there (What), what a strong entry has (Good) and an
     example (Example). Delete each comment when you fill its section. -->

PRD: <path>   Backlog: docs/product/backlog.md   Built: <date>

## Matrix

<!-- What: one row per live REQ: what it became, why, and the stories and
     AC ids that cover it. Withdrawn REQ are left out.
     Good: Judgement is one of story (it seeds one), criterion-of US-..,
     platform-detail-of US-.., duplicate-of REQ-.., split (into two
     stories), non-functional (a quality every named story's AC carries) or
     out-of-scope (the Why cites the Q-nnn decision that put it out); the
     Why says in one sentence why that judgement and not another, on every
     row, including story rows; the AC ids are real ids from backlog.md.
     Example: "REQ-015 | Match on date of birth | criterion-of US-00-014 |
     a condition on the match, not something a user does on its own |
     US-00-014 | AC-US-00-014-2" -->

| REQ | Statement (short) | Judgement | Why | Covered by | AC ids |
| --- | --- | --- | --- | --- | --- |
| REQ-001 | <first clause> | story / criterion-of US-.. / platform-detail-of US-.. / duplicate-of REQ-.. / split / non-functional / out-of-scope | <one sentence> | US-00-001 | AC-US-00-001-1 |

## Gaps

<!-- What: every REQ the gate reports with no acceptance criterion, and what
     should happen to it.
     Good: the reason is specific (no persona named, blocked on a Q-nnn) and
     the action names a skill, a story or a person.
     Example: "REQ-022 | depends on Q-004 (which lab formats) | answer
     Q-004, then add an AC to US-00-014" -->

| REQ | Why uncovered | Proposed action |
| --- | --- | --- |
| <none, or one row per REQ with no story> | | |

## Orphan stories

<!-- What: stories that cover no REQ, marked inferred:, for the user to
     accept or drop.
     Good: says why the story was written (a gap in an error path, a
     precondition another story needs); accepting it means prd adds the
     REQ, not this file.
     Example: "US-01-003 inferred: | undo a wrong match, needed by the error
     path in F1 step 4 | accept as REQ-031 via prd" -->

| Story | Reason it exists | Action |
| --- | --- | --- |
| <US-nn-nnn marked inferred:, or none> | | accept as REQ-nnn via prd / drop |

## Counts

<!-- What: the counts and verdict from the gate's last run.
     Good: copied from the script's lines verbatim; never a number the
     script did not print.
     Example: "stories-coverage: 31 REQ from docs/product/PRD.md (2
     withdrawn), 29 covered, 2 out of scope, 0 gaps, 12 stories, 58 AC,
     1 orphans, 0 problems" -->

<the coverage_check "stories-coverage:" line and its Verdict line, verbatim>
