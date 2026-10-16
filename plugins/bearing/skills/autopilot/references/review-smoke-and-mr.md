# autopilot: review, smoke and the merge request

Read at steps 9 and 10: branch-review, the smoke run, the headless smoke request, and the mr stage.

9. Review is `branch-review`; fix every Critical and High it confirms, then
`make check` again. `definition-of-done` walks the definition of done, including
item 13: start what the repository ships and drive its main flow,
sign-in first, against the real backend. A bug the smoke run finds is
fixed test first like any other, then the smoke runs again; the dod
gate refuses a smoke file older than the last commit. Headless
(`BRG_AUTOPILOT_HEADLESS=1`, set by `launch`) the sandbox keeps Docker
and `.env` out of reach: write the checks to
`.scratch/smoke-plan-<ID>.txt` (`base <url>`, then `METHOD /path
status` per line) unless the Makefile has a `smoke` target, run
`brg-autopilot smoke-request --id <ID>` and end your turn. The
launcher runs the smoke outside the sandbox and resumes the session
with the file and its verdict; at most 3 rounds. The plan runner starts
the stack with `make up` or a compose file; an app with neither (a
Next.js app on a hosted backend) needs a `smoke` target, which the
Next.js template has: it starts the standalone build with `.env.local`
and runs the same plan file. A status check passes in a unit test of
proxy.ts and can still fail on the real server (a rewrite's status is
ignored), which is why the smoke drives the built server.
10. The mr stage: `merge-request` prepares the description; `report` writes
`docs/autopilot/<run>.md`; commit it, and let that commit be the last
write (`git status` clean after it: a progress file touched later is
work the MR does not carry); paste its decisions table into
the description, with the exact push command (`git push -u origin
<branch>`) under it; print the same command in the last message. Do
not run it.
