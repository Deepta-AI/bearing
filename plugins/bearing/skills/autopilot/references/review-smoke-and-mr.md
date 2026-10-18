# autopilot: review, smoke and the merge request

Read at steps 9 and 10: branch-review, the smoke run, the headless smoke request, and the mr stage.

9. Review is `branch-review --unattended`, once (nobody answers its
questions, as with design-directions); it writes
`.scratch/review/<slug>/verdict.txt`, which the review gate reads. Fix
every Critical and High it confirms, test first, commit each fix and
append `<finding number> <commit sha>` to `.scratch/review/<slug>/fixed.txt`;
the gate checks every blocking number has a commit after the reviewed one
on this branch. Fixes are not re-reviewed. Then `make check` again. `definition-of-done --unattended` walks the definition of done, including
item 13: start what the repository ships and drive its main flow,
sign-in first, against the real backend. A bug the smoke run finds is
fixed test first like any other, then the smoke runs again; the dod
gate refuses a smoke file older than the last commit. Headless
(`BRG_AUTOPILOT_HEADLESS=1`, set by `launch`) the sandbox keeps Docker
and `.env` out of reach: write the checks to
`.scratch/smoke-plan-<ID>.txt` (`base <url>`, then `METHOD /path status`
per line) unless the Makefile has a `smoke` target, run
`brg-autopilot smoke-request --id <ID>` and end your turn. The
launcher runs the smoke outside the sandbox and resumes the session
with the file and its verdict; at most 3 rounds. The plan runner starts
the stack with `make up` or a compose file; an app with neither (a
Next.js app on a hosted backend) needs a `smoke` target, which the
Next.js template has: it starts the standalone build with `.env.local`
and runs the same plan file. A status check passes in a unit test of
proxy.ts and can still fail on the real server (a rewrite's status is
ignored), which is why the smoke drives the built server.
Item 14 runs every suite beyond unit in full and, unattended, leaves a suite
to CI only by a recorded decision; commit the report it writes
under `docs/testing/reports/` before `done dod`, since the dod gate takes
only that report as a change after the run's sha.
10. The mr stage: when `docs/architecture/repo-plan.json` holds more than
one entry, first write the `## Repos` section from it in the merge order
`${CLAUDE_PLUGIN_ROOT}/references/task-set.md` gives (unattended, that
order stands; nothing is asked):
`python3 "${CLAUDE_PLUGIN_ROOT}/skills/session-handoff/scripts/progress.py" write --task <ID> --repo "<n>. <Name> (<path>)"`,
one `--repo` per entry, this repository as `.`; the report lists, for
each sibling, the `start-task <ID> <Name> --repos <list>` line to run
there, and the report commit carries the progress file. Then
`merge-request` prepares the description; `report` writes
`docs/autopilot/<run>.md`; commit it, and let that commit be the last
write (`git status` clean after it: a progress file touched later is
work the MR does not carry); paste its decisions table into
the description, with the exact push command (`git push -u origin <branch>`)
under it. Then, in this order: `make check` again (the report commit is
newer than the gate marker, and `brg-push check` refuses a stale gate),
`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-push" check`, and on exit 0
`bash "${CLAUDE_PLUGIN_ROOT}/bin/brg-push" request`: the run's last Stop
pushes the branch from a fresh clone. This request replaces the one
`merge-request` made, which named the commit before the report.
Otherwise print the push command in the last message. Never run `git push`; unattended, never ask.
