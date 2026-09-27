---
name: gate-audit
description: 'Audits every gate (CI jobs, git hooks, make check, hook scripts) for passing on empty input, printing no count or asserting a constant. Use when asked to "audit the gates", "is this check real" or "check the CI checks".'
argument-hint: "[path or job name to limit the audit]"
allowed-tools: Read, Grep, Glob, Bash(make -n:*), Bash(ls:*), Bash(bash -n:*), Bash(python3 *skills/gate-audit/scripts/probe_gates.py*), Bash(mktemp -d:*), Bash(cp -R:*), Bash(make -C:*), Bash(git config --get:*)
---

# gate-audit

A gate is a promise: "if this is wrong, the merge stops". The audit checks
each promise against the repository, not against the green badge. A green
`make check` or pipeline is the claim under test, never evidence.

## Inputs

- CI file: `.gitlab-ci.yml`; if absent, `.github/workflows/*.yml`,
  `Jenkinsfile`, `.circleci/config.yml`, `bitbucket-pipelines.yml`.
- Hooks: `.githooks/`; if absent, `.husky/`, `lefthook.yml`,
  `.pre-commit-config.yaml`, and `.claude/settings.json` hook scripts.
- Makefile: `check` and every target it depends on; if absent,
  `package.json` scripts named `check`, `lint`, `test`, or `justfile`
  recipes.
- The promises: README, CONTRIBUTING, CHANGELOG entries and ADRs that say
  what a gate does, where it runs or what it blocks, and any contract
  file (schema, API spec) a gate claims to enforce.
- Zero CI files, hooks and check targets is the audit's result: report
  "0 gates found: no CI file, no hooks, no check target" as a failed audit
  and suggest `ci-pipeline`, `git-hooks` and a Makefile `check` target.
- Limit: `$ARGUMENTS`, a path or job name; if absent, every gate.
- The request is for a verdict. Change nothing in the repository and make
  no commit unless the user asked for fixes; every experiment runs in a
  scratch copy.

## Steps

1. Inventory in one batch: every CI job with a `script` or `run` step,
   every hook, `check` and its prerequisites, every script they call, and
   every sentence in the documents above that promises something about a
   gate. Print the count and the sources before judging.
2. Run the probe:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/gate-audit/scripts/probe_gates.py" --repo .`
   (`--only <name>`, `--timeout <s>`, default 120). It runs each make gate
   on an emptied copy and on a copy of the repository as it is, runs each
   hook on an empty repository, and reads the CI file and hooks. Its
   lines: `gate:` (both runs, exit and count), `ci-job:` (what keeps a
   job from blocking, how many files a `changes` rule matches), `hooks:`
   (who sets core.hooksPath), `problem:`, `not probed:`, and a
   `gate-probe:` counts line. It exits 1 on any problem and on zero gates.
   A `problem:` line is a lead, not a verdict: confirm it by reading the
   code.
3. Count the population yourself, independently of the gate: how many
   files, tests, migrations, queries or events exist that the gate claims
   to cover (`git ls-files`, a glob, `grep -c`). Compare with what the gate
   examined on the repository run. A gate that prints "ok" and examined 0
   of 4 is fake even though it passes on real input; a test gate that
   collects 3 of 5 test functions has a blind spot. Common reasons: a path
   or glob relative to the wrong directory, a test file outside the
   runner's name pattern, a `git ls-files` pathspec that matches nothing.
4. Read each gate for the traps the probe cannot run:
   - Exit-code escapes: `|| true`, `|| [ $? -eq 5 ]` (pytest's "no tests
     collected"), `|| exit 0`, `set +e`, a `-` recipe prefix, a pipeline
     without `pipefail` whose last command is `echo` or `xargs -r`.
   - Numeric tests on a parsed value: `if [ "$total" -lt N ]` with an
     empty or non-numeric `$total` is an error, `if` treats it as false,
     and the `else` branch prints "ok". Ask what the gate does when the
     value cannot be read.
   - Circular checks: a schema generated from the data it then validates,
     a snapshot regenerated in the same run, a test asserting a constant
     against itself, a threshold set below current measurement. Find the
     real reference (the contract in docs/, the ADR's number) and check
     the data against it.
   - Thresholds: compare the configured floor with the documented
     decision and with a measured value; a floor far below both cannot
     catch the regression it was written for.
   - CI blocking path: `allow_failure`, `continue-on-error`, `when:
     manual`, `rules: changes` or `paths:` that match no file (count the
     matches), a check prerequisite that no blocking job runs, a
     job image that lacks the tool the script calls.
   - Hooks: installed only if something sets core.hooksPath (or husky,
     lefthook, pre-commit install); a README step is not installation. A
     hook is local and skippable (`--no-verify`), so a rule that matters
     needs a CI twin. A pre-commit hook that rewrites files and runs `git
     add "$f"` commits the unstaged hunks of every file it touches. A hook
     ending in `exit 0` cannot block.
5. Prove the verdicts that matter by mutation, in a scratch copy
   (`d=$(mktemp -d) && cp -R . "$d/repo"`, then `make -C "$d/repo" <gate>`):
   plant the defect the gate exists to catch (delete a down migration,
   drop a required field, delete a test file, add `SELECT *`) and run the
   gate. Green on the planted defect is a fake gate, shown. Red is a real
   gate, and say so: a verdict of "real" needs evidence as much as "fake".
   Where a measured number decides the verdict (coverage, file counts),
   measure it; if you cannot run it, say "not run".
6. Check every promise from step 1 against what the code does: "CI runs
   the same gates", "blocks a merge", "enforced by the hook". A promise
   the configuration breaks is a finding in its own right, next to the
   gate it names.
7. For each gate that needs work, give its fix, including the CI and hook
   configuration ones (remove `allow_failure`, a `changes` path that
   matches, run the gate in the blocking job, a make target that sets
   core.hooksPath plus a CI check). Then say what the fix will turn red:
   a gate made real reports the defects it was hiding (the missing down
   migration, the stale fixture, the `SELECT *` query), so name each one
   and say it must be fixed in the same change or first, or the check target
   and CI go red the moment the gate is corrected.

## Output contract

```
## Gate audit: <N> gates found (CI <a>, hooks <b>, make <c>), <K> need work
<probe_gates.py "gate-probe:" counts line, verbatim>
| Gate | Verdict | What it examined (repo run / population) | Evidence: ran or read | Fix | Turns red when fixed |
Promises broken: <doc, sentence, what the configuration does instead>
Real and proven: <gates shown to catch a planted defect>
Not run: <each thing not executed, including all CI behaviour: CI cannot run here>
```

Verdicts: real, fake (checks nothing or passes on the defect it exists
for), weak (checks something, but not what it promises), not blocking (a
real check that cannot stop a merge or commit).

## Gotchas

- CI runs nowhere in this session. Read the CI file; never write "CI
  ran", "the job passed" or "never runs" as an observation. Say "by
  reading .gitlab-ci.yml".
- The probe's empty copy keeps only the machinery; a gate whose input is
  a file the probe kept can pass there. Read the `kept` list.
- "Same output on the repository as on empty input" means nothing shows
  the gate examined anything; a real linter that prints nothing trips it
  too. Settle it with step 3's count.
- A format-only hook is not a gate. A formatter that rewrites and
  re-stages is a side effect to report, not a check.
- Numbers in the report come from a command you ran or a file you read;
  a number from neither is not written.
- A repository with a CI file but no hooks (or the reverse) is audited on
  what it has; the missing layer is one line, not a stop.
