# Skill-evals driver: unattended measurement for the scoreboard

Status: draft for review, 2026-10-19. Branch `feat/NOTASK-2-SkillEvalsDriver`,
stacked on `feat/NOTASK-1-ScheduledEvals`. Step 2 of the harness
improvement plan.

## Goal

NOTASK-1 put trigger-eval and harness-eval on a weekly timer and left the
scoreboard's `skill_evals` slot `null`. That slot is the one that says
whether a skill beats no skill. Today a maintainer's session has to drive
`bin/skill-evals.py` by hand, and nothing has been measured. This task
makes it run unattended over a small rotating set each week.

## Design

- `bin/skill-evals-run.py` drives the existing commands for each chosen
  skill: `prepare` (next free iteration), one `claude -p` executor per
  run folder with `prompt.txt`, `timing` from the session's JSON result,
  `grade-prompt`, one `claude -p` grader per case, `unblind`, then
  `measure`. It writes `summary.json` for the scoreboard.
- Isolation for every session: Claude Code's Bash sandbox on and required,
  network limited to localhost, credential folders unreadable, the Skill
  tool and browser tools off, no user or project settings. The executor
  prompt already forbids push, deploy and network installs; the sandbox
  enforces it.
- Rotation: the tracked `evals/scoreboard.jsonl` holds each skill's last
  measured commit. Skills whose skill folder or `evals/<name>/` changed
  since then come first, then skills never measured, then the oldest
  measured. `--max` caps the set (default 5; about 20 executor and 10
  grader sessions a week).
- `bin/eval-scoreboard.py --skill-evals <summary.json>` writes per-skill
  arm pass rates, margin, cases and commit into the row. A regression is
  a skill whose with_skill pass rate fell by more than `--max-skill-drop`
  (default 0.10) since that skill's previous measurement in any earlier
  row.
- `bin/evals-weekly.sh` runs the driver after the two suites.
- `bin/skill-evals.py` takes `BRG_SKILL_EVALS_WS` and
  `BRG_SKILL_EVALS_PRIVATE` so tests stay out of `.scratch`, and its
  docstring now says the scoreboard is tracked and read by no site.

## Failure rules

- Zero skills chosen, or every chosen skill failing to measure: exit 1,
  with the count printed.
- A skill that fails mid-way is recorded with its error in the summary
  and the next skill still runs.

## Non-goals

- Tuning skills from the results (the propose, probe, keep loop is next).
- Publishing the numbers on either site.
