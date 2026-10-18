# autopilot: the build and what follows it

Read at steps 7 and 8: test first story by story, parallel subagents, test-automation, LLM stages and the design critique bar.

7. Build is test first, story by story, in the order of the backlog:
a failing test named for the story, the code, `make check`, a commit
per story with the task id. Where the Makefile records a build pass
(the Next.js and React templates do), `make build` runs too before the
stage is done: a page that cannot prerender passes every check and
fails only the build. Those templates' build also holds the bundle
budget, so an app that grew past it fails here, not first in CI; cut
the bundle, never raise the budget to the measurement. The edit hook's lint findings are fixed
when they arrive; the Stop hook's `make check` demand is met, not
argued with. No test asserts on wall-clock time: it passes on the
laptop and flakes in CI. Before the first line of code, read the
traps in references/reviewer-checks.md and put the ones that apply into the tests.
A build split across parallel subagents gives each a disjoint set of
files and a migration timestamp range, forbids git commands that
change state, and has the supervisor commit. Each agent's checks stay
scoped to its own files: with one shared local database, a reset by
one agent fails another's `make test-db` mid-run, so an agent reruns
only its own pgTAP file (`supabase test db <file>`) and the
supervisor runs the full `make test-db` once the batch lands. Other
agents' type and lint errors are listed, not fixed.
8. After the build: test-automation names a test after every case
that is not manual-only or retired (its TC id in the test name); with
llm in the profile, llm-guardrails writes `guardrails/policy.yaml` and
wires it at the call sites, and llm-eval writes `docs/genai/evals.md`
(an eval that needs a provider key the run lacks is written and marked
not run, never reported as passed); for a
UI, design-critique --unattended scores the design gallery of the running app
(`make dev`) across every screen and state, fixes the top findings
and re-scores until the bar holds: overall 8.0, no category below 7,
every screenshot present. The design_review gate reads the report;
a design under the bar is not done, however many stages passed.
