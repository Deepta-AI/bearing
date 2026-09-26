#!/usr/bin/env bash
# tests/unit/stories_coverage.sh: plugins/bearing/skills/backlog/scripts/coverage_check.py
# passes a covered backlog and fails, with the reason, on an uncovered REQ,
# a Covers naming an unknown REQ, a story-level REQ no AC names, an epic
# without a journey, a missing matrix row or Why, a story missing its
# objective, quotes or exclusions, a bad task table, a bad question
# register, and on empty input. Coverage is computed from the AC Covers
# lines, so a matrix that claims "covered" does not rescue a gap.
set -u
. "$(dirname "$0")/../lib/assert.sh"
CHK="$KIT/plugins/bearing/skills/backlog/scripts/coverage_check.py"

# fixture <dir>: a PRD with REQ-001..003 (004 withdrawn) and objective B1,
# two stories with an index, tasks, questions, flows and a matrix.
fixture() {
  mkdir -p "$1"
  cat > "$1/PRD.md" <<'MD'
| # | Objective |
| --- | --- |
| B1 | Operators see what runs |

| Id | Statement |
| --- | --- |
| REQ-001 | List ports |
| REQ-002 | Show the owning process |
| REQ-003 | Export as JSON |
| REQ-004 | withdrawn: sort by memory |
MD
  cat > "$1/backlog.md" <<'MD'
## Story index

| Story | Epic | Title | Points |
| --- | --- | --- | --- |
| US-00-001 | EP-01 | List ports with owners | 3 |
| US-00-002 | EP-02 | Print JSON | TBD |

## EP-01 See what runs

### US-00-001 List ports with owners

Epic: EP-01   Priority: Must   Points: 3
Covers: REQ-001, REQ-002

**Why it matters.** B1: the list is what an operator reads first.

**From the PRD.**
- REQ-001: "List ports"
- REQ-002: "Show the owning process"

**Acceptance criteria.**

- AC-US-00-001-1. Given a listener, when I run it, then the port shows.
  Covers: REQ-001
- AC-US-00-001-2. Given a listener, when I run it, then the pid shows.
  Covers: REQ-002

**Not in this story.**
- Sorting by memory (REQ-004 is withdrawn).

## EP-02 Script it

### US-00-002 Print JSON

Epic: EP-02   Priority: Should   Points: TBD (estimate)
Covers: REQ-003

**Why it matters.** B1: scripts read the same list.

**From the PRD.**
- REQ-003: "Export as JSON"

**Acceptance criteria.**

- AC-US-00-002-1. Given --json, when I run it, then stdout is JSON.
  Covers: REQ-003

**Not in this story.**
- CSV output.
MD
  cat > "$1/tasks.md" <<'MD'
| Task | Story | Discipline | Title | Estimate (h) | Depends on | Done when | Verifies |
| --- | --- | --- | --- | --- | --- | --- | --- |
| US-00-001-D1 | US-00-001 | backend | Read the socket table | 4 | none | ports and pids print | AC-US-00-001-1, AC-US-00-001-2 |
| US-00-001-T1 | US-00-001 | qa | Cases for the list | 2 | US-00-001-D1 | cases pass | AC-US-00-001-1, AC-US-00-001-2 |
| US-00-002-D1 | US-00-002 | backend | JSON writer | TBD | US-00-001-D1 | valid JSON printed | AC-US-00-002-1 |
| US-00-002-T1 | US-00-002 | qa | Cases for --json | 1.5 | US-00-002-D1 | cases pass | AC-US-00-002-1 |
MD
  cat > "$1/questions.md" <<'MD'
## Needs your confirmation

- Q-001 JSON schema version. Assumed: v1, flat.

## Register

| Q | Status | Kind | Where | Basis | Question | Readings | Decision | Why | Affects |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Q-001 | open | gap | REQ-003 | assumption | Which JSON shape? | (a) flat; (b) nested | flat list | simplest to pipe | US-00-002 |
| Q-002 | open | gap | REQ-001 | convention | IPv6 too? | (a) v4 only; (b) both | both | house standard | US-00-001 |
MD
  printf '## Flow F1 (EP-01)\n## Flow F2 (EP-02)\n' > "$1/user-flows.md"
  cat > "$1/coverage.md" <<'MD'
## Matrix

| REQ | Statement (short) | Judgement | Why | Covered by | AC ids |
| --- | --- | --- | --- | --- | --- |
| REQ-001 | a | story | seeds the list | US-00-001 | AC-US-00-001-1 |
| REQ-002 | b | criterion-of US-00-001 | a column of the same list | US-00-001 | AC-US-00-001-2 |
| REQ-003 | c | story | a second output | US-00-002 | AC-US-00-002-1 |

## Gaps

Verdict: covered
MD
}
run() { python3 "$CHK" --prd "$1/PRD.md" --backlog "$1/backlog.md" --coverage "$1/coverage.md" --flows "$1/user-flows.md" --tasks "$1/tasks.md" --questions "$1/questions.md"; }

t_begin "a covered backlog passes with its counts, tasks and questions"
d="$(tmpdir)/ok"; fixture "$d"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "stories-coverage: 3 REQ from $d/PRD.md (1 withdrawn), 3 covered, 0 out of scope, 0 gaps, 2 stories, 3 AC, 0 orphans, 0 problems"
assert_contains "$T_OUT" "tasks: 4 (2 development, 2 test), hours by discipline: backend 4, qa 3.5; total 7.5 h, 1 TBD"
assert_contains "$T_OUT" "questions: 2 (open 2, needs confirmation 1)"
assert_contains "$T_OUT" "Verdict: covered"
t_end

t_begin "an AC that loses its Covers line leaves a gap, whatever the matrix says"
d="$(tmpdir)/gap"; fixture "$d"
sed -i.bak '/AC-US-00-002-1\. Given/{n;d;}' "$d/backlog.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "gap: REQ-003 has no acceptance criterion covering it"
assert_contains "$T_OUT" "problem: US-00-002: story covers REQ-003 but none of its AC names it"
assert_contains "$T_OUT" "Verdict: not covered"
t_end

t_begin "a Covers naming an unknown or withdrawn REQ is a problem"
d="$(tmpdir)/unknown"; fixture "$d"
sed -i.bak 's/  Covers: REQ-003/  Covers: REQ-003, REQ-009, REQ-004/' "$d/backlog.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "covers REQ-009, which is not a PRD statement"
assert_contains "$T_OUT" "covers REQ-004, which the PRD marks withdrawn:"
t_end

t_begin "an epic without a journey, a REQ without a matrix row and a row without Why are problems"
d="$(tmpdir)/flows"; fixture "$d"
printf '## Flow F1 (EP-01)\n' > "$d/user-flows.md"
sed -i.bak '/| REQ-002 |/d; s/| a second output |/| |/' "$d/coverage.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "EP-02: no journey"
assert_contains "$T_OUT" "REQ-002: no row in the"
assert_contains "$T_OUT" "REQ-003: the matrix row has no Why"
t_end

t_begin "out-of-scope needs a Q-nnn decision and is counted apart, not as a gap"
d="$(tmpdir)/oos"; fixture "$d"
sed -i.bak 's/REQ-003/REQ-001/g' "$d/backlog.md"
sed -i.bak 's/| REQ-003 | c | story | a second output |/| REQ-003 | c | out-of-scope | deferred |/' "$d/coverage.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "REQ-003: out-of-scope with no Q-nnn decision in Why"
sed -i.bak 's/| deferred |/| deferred by Q-001 |/' "$d/coverage.md"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "2 covered, 1 out of scope, 0 gaps"
sed -i.bak 's/by Q-001/by Q-009/' "$d/coverage.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "REQ-003: Why cites Q-009, which is not in"
t_end

t_begin "a story without its objective, quotes, exclusions or index row is a problem"
d="$(tmpdir)/story"; fixture "$d"
sed -i.bak 's/B1: scripts/B7: scripts/; /- REQ-001: "List ports"/d; /^- CSV output\.$/d; /^| US-00-002 | EP-02/d' "$d/backlog.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "US-00-002: B7 is not a business objective in the PRD"
assert_contains "$T_OUT" "US-00-001: covers REQ-001 but 'From the PRD' does not quote it"
assert_contains "$T_OUT" "US-00-002: 'Not in this story' has no entry"
assert_contains "$T_OUT" "story index: US-00-002 has no row"
t_end

t_begin "a story over seven AC and a Points mismatch are problems"
d="$(tmpdir)/ac"; fixture "$d"
for k in 3 4 5 6 7 8; do printf -- '- AC-US-00-001-%s. Given x, when y, then z.\n  Covers: REQ-001\n' "$k"; done > "$d/extra"
python3 -c 'import sys; p = sys.argv[1]; s = open(p).read(); x = open(sys.argv[2]).read(); open(p, "w").write(s.replace("  Covers: REQ-002\n", "  Covers: REQ-002\n" + x, 1))' "$d/backlog.md" "$d/extra"
sed -i.bak 's/| US-00-001 | EP-01 | List ports with owners | 3 |/| US-00-001 | EP-01 | List ports with owners | 5 |/' "$d/backlog.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "acceptance criteria, over 7 (split the story)"
assert_contains "$T_OUT" "story index: US-00-001 Points '5' differs from the story's '3'"
t_end

t_begin "tasks: bad ids, disciplines, estimates, dependencies and untested AC fail"
d="$(tmpdir)/tasks"; fixture "$d"
sed -i.bak 's/| US-00-001-T1 | US-00-001 | qa | Cases for the list | 2 | US-00-001-D1 | cases pass | AC-US-00-001-1, AC-US-00-001-2 |/| US-00-001-T1 | US-00-001 | backend | Cases for the list | 12 | US-00-001-D9 | | AC-US-00-001-1 |/' "$d/tasks.md"
sed -i.bak 's/| US-00-002-D1 | US-00-002 | backend/| US-00-002-D1 | US-00-002 | design/' "$d/tasks.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "US-00-001-T1: a test task is qa, not backend"
assert_contains "$T_OUT" "US-00-001-T1: 12 h is over a day; split the task"
assert_contains "$T_OUT" "US-00-001-T1: depends on US-00-001-D9, which is not a task"
assert_contains "$T_OUT" "US-00-001-T1: Done when is blank"
assert_contains "$T_OUT" "AC-US-00-001-2: no test task verifies it"
assert_contains "$T_OUT" "US-00-002-D1: discipline 'design' is not one of"
sed -i.bak '/US-00-002-T1/d' "$d/tasks.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "US-00-002: no test task in"
rm "$d/tasks.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "no tasks at $d/tasks.md"
t_end

t_begin "questions: empty Affects, bad values and an assumption out of place fail"
d="$(tmpdir)/q"; fixture "$d"
sed -i.bak 's/| house standard | US-00-001 |/| house standard | |/; s/| open | gap | REQ-001 | convention |/| maybe | risk | REQ-009 | guess |/' "$d/questions.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "Q-002: Affects names no story"
assert_contains "$T_OUT" "Q-002: status 'maybe' is not open or confirmed"
assert_contains "$T_OUT" "Q-002: kind 'risk' is not open-question, gap or contradiction"
assert_contains "$T_OUT" "Q-002: basis 'guess' is not stated"
assert_contains "$T_OUT" "Q-002: Where names REQ-009, which is not a PRD statement"
fixture "$d"
sed -i.bak 's/| open | gap | REQ-001 | convention |/| open | gap | REQ-001 | assumption |/' "$d/questions.md"
sed -i.bak 's/| open | gap | REQ-003 | assumption |/| confirmed | gap | REQ-003 | assumption |/' "$d/questions.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "Q-002: an open assumption listed after Q-001; assumptions come first"
assert_contains "$T_OUT" "Q-002: open assumption missing from 'Needs your confirmation'"
assert_contains "$T_OUT" "Q-001: under 'Needs your confirmation' but not an open assumption"
printf '# Questions\n\nNo open questions: the PRD left nothing open.\n' > "$d/questions.md"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "questions: 0 (open 0, needs confirmation 0)"
printf '# Questions\n' > "$d/questions.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 Q-nnn rows"
t_end

t_begin "a withdrawn story does not cover"
d="$(tmpdir)/wd"; fixture "$d"
sed -i.bak 's/^### US-00-002 Print JSON/### US-00-002 Print JSON (withdrawn: moved to v2)/' "$d/backlog.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "gap: REQ-003"
t_end

t_begin "zero REQ, a missing backlog and zero stories fail"
d="$(tmpdir)/empty"; fixture "$d"
printf '# PRD\n' > "$d/PRD.md"; rm "$d/coverage.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 REQ statements read"
fixture "$d"; rm "$d/backlog.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "no backlog at"
printf '## EP-01 nothing\n' > "$d/backlog.md"
assert_exit 1 run "$d"
assert_contains "$T_OUT" "0 stories"
t_end

t_begin "inline statements in coverage.md stand in for a missing PRD"
d="$(tmpdir)/inline"; fixture "$d"
rm "$d/PRD.md"
{ printf '## Statements (inline, from README)\n\n| REQ-001 | a |\n| REQ-002 | b |\n| REQ-003 | c |\n\n'; cat "$d/coverage.md"; } > "$d/c2.md"
mv "$d/c2.md" "$d/coverage.md"
assert_exit 0 run "$d"
assert_contains "$T_OUT" "3 REQ from $d/coverage.md"
t_end

t_summary
