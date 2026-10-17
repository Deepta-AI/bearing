# backlog: what the coverage gate checks

Read when: step 9: running coverage_check.py and reading what it fails on.

9. Run the gate:
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/backlog/scripts/coverage_check.py"`
(add `--prd <path>` when `$1` named another PRD). It detects the id
scheme from the committed backlog (`--story-id REGEX` overrides) and
checks tasks.md and questions.md when they exist. It computes coverage
from the AC `Covers:` lines (an adopted backlog may trace at story
level, and a definition of done may carry a non-functional REQ) and
fails on a story id at HEAD that is gone or renumbered, a withdrawn id
made live, a live story covering a withdrawn REQ with no question
raised, a withdrawn story that code or tests outside docs/ still name
with no question raised, an uncovered REQ, an unknown or
withdrawn REQ in a Covers line, a story over seven AC, a story without
its objective, quotes or exclusions, an index row missing or out of
step, a matrix row without its judgement or why, an out-of-scope REQ
with no Q-nnn, an epic with no journey, a task table that breaks the
rules in step 6, and a register row with an empty Affects or an
assumption outside "Needs your confirmation". The house-format blocks
(objective, quotes, exclusions, Points) are checked on a US-nn-nnn
backlog only. Fix what it reports and rerun until it exits 0. Copy its
"tasks:" line into the backlog's "Hours by discipline" (full pack) and
its counts line into coverage.md.
