# autopilot: start, and the repo and branch stages

Read at step 1: what the repo stage adds to an existing repository, a documents-only repository, and the branch stage.

1. Start or resume: `python3 "${CLAUDE_PLUGIN_ROOT}/bin/brg-autopilot" start "<statement>"`,
or `status` then `next` on `--resume`. Print the run id.
1a. The repo stage on an existing repository. The gates read a git
repository, a Makefile `check` target that records a pass
(`.bearing/state/.check-passed`), and `.scratch/` and
`.bearing/state/` kept out of git. Whatever of that is present
stays as it is; `done repo` passing on the untouched repository is
the expected case. What is missing is added at its smallest: the
one recipe line `@mkdir -p .bearing/state && touch .bearing/state/.check-passed`
at the end of `check`, a `check` that
runs the repository's own test command when there is none, the two
ignore lines. No CI, hooks, templates, rules files, AGENTS.md or
CLAUDE.md, and no rewrite of the build: the first run on a 227-line
feature adopted 39 files and rewrote CI and the Makefile, a 3,700-line
diff nobody asked to review. What the repository lacks against the
standard goes in the report under Noticed, as a proposal.
1b. A repository that holds only documents (a PRD, ADRs and an HLD
written before any code) is a new product, scope full: the repo
stage scaffolds the stack into it with `brg-scaffold`, which keeps
every existing file, and the repo plan entry that lives here gets
`"path": "."`.
1c. The branch stage comes next, before any document: `start-task`
names it (`feature/NOTASK-<n>-<Name>` without a tracker), so every
later stage commits on the task branch and the trunk is never
written.
