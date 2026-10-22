# Scheduled evals: a weekly run and a tracked scoreboard

Status: draft for review, 2026-10-19. Branch `feat/NOTASK-1-ScheduledEvals`.
Step 1 of the harness improvement plan. Step 2 (a headless skill-evals
driver over a rotating set of skills) is NOTASK-2 and gets its own spec.

## Goal

Bearing has the evals but nothing runs them on a schedule, so no one can
say whether a change made the kit better or worse. `make check` proves
the evals exist; it does not prove the skills pass them. This task makes
the two headless suites run every week and keeps their numbers in a file
the repository tracks, so a merge request can show its effect on the
score.

## Decisions (2026-10-19, the maintainer)

- The scoreboard is tracked in git and not published: the handbook and
  the developer guide do not read it.
- The run is a user-level systemd timer on the maintainer's machine,
  using the claude CLI signed in to the subscription. No API key, no CI
  runner.
- skill-evals is out of scope here. Its slot in each scoreboard row is
  `null` until NOTASK-2 fills it.

## Design

- `bin/evals-weekly.sh` runs `bin/trigger-eval.py` and
  `bin/harness-eval.py`, each into a fresh output folder, then
  `bin/eval-scoreboard.py` on the two `results.json` files. It refuses a
  dirty tree, because the row records the commit it measured. It exits
  non-zero when any of the three did.
- `bin/eval-scoreboard.py` appends one JSON line to
  `evals/scoreboard.jsonl` per run: date, commit, trigger totals (cases,
  errored, recall, false-trigger rate) and per skill, harness pass rate
  per scenario, and `skill_evals: null`. It compares the row with the
  previous one and prints what moved.
  - Fails with nothing written when it checked zero cases or a results
    file is missing.
  - Fails, after writing the row, on a regression: recall down or the
    false-trigger rate up by more than `--max-drop` (default 5 points),
    or any harness scenario's pass rate lower than last time. The row is
    kept so the history stays honest.
  - Per-skill changes are listed and never fail the run: three requests
    a skill is too few to gate on.
- A single file, not a folder: `lint-evals` reads every folder under
  `evals/` as a skill.
- `make evals-weekly` runs it now. `make evals-timer` prints the two
  systemd units for this clone and the commands that install them; it
  installs nothing.

## Non-goals

- Running skill-evals, grading or tuning skills (NOTASK-2 and later).
- Committing the row: the maintainer commits `evals/scoreboard.jsonl`.
- Showing the scoreboard on either site.
