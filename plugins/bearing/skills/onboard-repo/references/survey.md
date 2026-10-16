# onboard-repo: the survey, fact by fact

Read when you run step 1 and need what to record for the gate, hooks, conventions, owners, ignore rules and secrets.

1. **Survey.** Record each fact with the file or command that shows it;
   the rest of the run is checked against this list.
   - Gate: every CI job (`.gitlab-ci.yml`, `.github/workflows/*`): its
     working directory, commands, flags (markers, tags, `-race`),
     variables (top-level and per job: `TZ`, `LANG`, feature flags),
     services it starts, `allow_failure`, `rules`/`only`. Run each
     offline job's commands locally, exactly as written, and note the
     counts (files linted, tests run, skipped, deselected). A test that
     skips unless a job variable is set is the usual reason a local run
     reports fewer passes than CI.
   - Scripts CI calls (the test or lint script in package.json, a tox
     env): changing one changes CI, so treat it as a CI change.
   - Existing Makefile: its targets and what `check` really runs versus
     what the README or CONTRIBUTING claims it runs.
   - Hooks: `git config --get core.hooksPath`; `ls .git/hooks` for
     non-sample files and their first lines (pre-commit framework, Husky,
     lefthook, a hand-written hook); `.pre-commit-config.yaml`, `.husky/`,
     `lefthook.yml`, a `prepare` script, a `setup` target that sets the
     hook path. Tools the hooks call and whether they are installed here.
   - Conventions: commit format from CONTRIBUTING and from
     `git log --format=%s -30` (where they disagree, the history is what a
     hook meets tomorrow, and the disagreement is a finding); whether the
     team merges or commits straight to the default branch
     (`git log --merges --oneline -5` empty and linear history on main
     means direct commits); branch names in use.
   - Owners: which CODEOWNERS file the host reads. GitLab takes the first
     of `CODEOWNERS`, `docs/CODEOWNERS`, `.gitlab/CODEOWNERS`; GitHub the
     first of `.github/`, root, `docs/`. A new root file shadows the
     team's real one.
   - Ignore rules: `git check-ignore -v .claude/settings.json AGENTS.md`
     for every path you intend to add.
   - Package manager from the lockfile (`package-lock.json` or none: npm;
     `pnpm-lock.yaml`; `yarn.lock`; `uv.lock`; `poetry.lock`).
   - Tracked secrets: `git ls-files` for `.env*` (not `.example`), `*.pem`,
     `*.key`, credentials JSON. Note the path only; do not open it or
     print a value.
   - Agent notes already here: CLAUDE.md, AGENTS.md, `.cursorrules`,
     README sections with rules. Their rules are the most valuable text in
     the repository.
   - Doc claims that the survey falsifies (README test commands that fail
     from where it says to run them, "make check runs what CI runs", a
     setup step naming a file, service or target the repository does not
     have). Do not copy a false claim into AGENTS.md.
