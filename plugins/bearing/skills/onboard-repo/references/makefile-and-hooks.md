# onboard-repo: the Makefile gate and fitting hooks to the team

Read when you write the check target (step 3) or write a hook (step 5).

- Fail on what CI fails on. A lister such as gofmt -l exits 0 while
  it lists unformatted files; CI wraps it in test -z, and so must the
  gate. Prove each check by making it fail once on a scratch file, then
  remove the file.
- Commands use the repository's package manager and run where the
  module is (no `go test ./...` at a root with no `go.mod`).
- The gate must pass on this machine with no arguments. Resolve tools
  the way the engineer's shell does: `python3` on PATH is often not the
  interpreter that has pytest (a newer system Python beside a
  `pytest` from another one). Pick the one that works here (for
  example the interpreter behind `pytest` on PATH), keep it
  overridable, and fail with the install line only when none has it.
- Compare counts with CI's, including skips: a job variable that
  unlocks a test belongs in the target, or `check` passes on less.

- Fit every hook you write, active or not, to the survey. The kit's
  hooks carry the kit's policy (Conventional types, 72-character
  subjects, task ids, em dash and AI-trailer bans, prose checks, no
  push from main); each rule is a new refusal for this team. Run the
  commit-msg hook on every subject in the history (up to the last 100)
  and get zero rejections by following the team's format, not the
  kit's; drop pre-push rules the practice breaks (push from main,
  task-id branch names, terminal confirmation, refusing a push of zero
  new commits such as a tag). A pre-commit hook must let a reword
  (`--amend` with nothing staged) and an `--allow-empty` commit through.
  Cut branches for stacks the repository does not have. Any refusal
  that stays is named in the report as a change the team must agree to.
