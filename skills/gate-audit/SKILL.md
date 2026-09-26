---
name: gate-audit
description: 'Audits every gate (CI jobs, git hooks, make check, hook scripts) for passing on empty input, printing no count or asserting a constant. Use when asked to "audit the gates", "is this check real" or "check the CI checks".'
argument-hint: "[path or job name to limit the audit]"
allowed-tools: Read, Grep, Glob, Bash(make -n:*), Bash(ls:*), Bash(bash -n:*), Bash(python3 *skills/gate-audit/scripts/probe_gates.py*)
---

# gate-audit

A gate is a promise. This skill checks the promise is real.

## Inputs

- CI file: looks in `.gitlab-ci.yml`; if absent, `.github/workflows/*.yml`,
  `Jenkinsfile`, `.circleci/config.yml`, `bitbucket-pipelines.yml`.
- Hooks: looks in `.githooks/`; if absent, `.husky/`, `lefthook.yml`,
  `.pre-commit-config.yaml`, and `.claude/settings.json` hook scripts.
- Makefile: `check` and every target it depends on; if absent, `package.json`
  scripts named `check`, `lint`, `test`, or `justfile` recipes.
- Any one of the three is enough to run. Zero of them is the audit's
  result, not a missing input: report "0 gates found: no CI file, no
  hooks, no check target" as a failed audit and suggest `ci-pipeline`,
  `git-hooks` and a Makefile `check` target.
- Limit: `$ARGUMENTS`, a path or job name; if absent, every gate.
- Probe: `scripts/probe_gates.py` in this skill, Python 3 only. It runs
  each make gate (check prerequisites and CI `make` calls) and each git
  hook once, in a throwaway copy (a fresh git repository) that keeps
  only the Makefile, tool configs and the scripts the gate invokes, with
  a timeout and the package managers set offline; the repository is never written. A gate
  that names the network, a database, a cluster, deploy or publish is
  "not probed" with the reason.

## Steps

1. Inventory the gates in one batch from the locations in Inputs: every
   job with a `script` (or `run` step), every hook, `check` and its
   dependencies, and any script a job or hook calls. Print the count and
   the sources before judging anything.
2. For each gate answer three questions by reading its code:
   - Empty input: what happens when there are zero files, zero tests, zero
     commits, zero resources. It must fail or say "0 ... nothing checked"
     and exit non-zero. `find | xargs tool` with no matches, `git ls-files`
     on an unstaged tree, `grep -c` piped into a test, and `for f in
     $(...)` loops are the usual culprits.
   - Count: does the success line say how many things were verified
     ("6 files formatted", "12 packages tested", "3 overlays, 27
     resources")? A bare "ok" or a tool's silent exit is a miss.
   - Real quantity: does it check something the code did not itself
     choose? A test asserting a constant against the same constant, a
     schema check against the schema that generated the data, a coverage
     threshold set below current coverage are misses.
3. Run the empty-input proof:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/gate-audit/scripts/probe_gates.py" --repo .`
   (add `--only <name>` for the limit and `--timeout <s>`, default 120).
   It prints a `gate:` line per probed gate (fails or PASSES on empty
   input, the count line it printed or none, the files it kept), a
   `not probed:` line with the reason, a `problem:` line per gate that
   passes on empty input or prints no count, and a `gate-probe:` counts
   line; it exits 1 on any problem and on zero gates found or probed.
   The Empty input and Count columns come from it. For a gate not
   probed, and for CI jobs that call no make target, fall back to the
   cheap proofs: `make -n <target>` to see the real command, `bash -n` on
   scripts, the tool's `--help` for empty-input behaviour, and say
   "unverified" when you cannot. Real quantity stays a reading judgement.
4. Report per gate. Suggest the fix in one line each (`[ "$n" -gt 0 ] ||
   exit 1`, print the count, compare against a measured value).

## Output contract

```
## Gate audit: <N> gates found (CI <a>, hooks <b>, make <c>)
<probe_gates.py "gate-probe:" counts line, verbatim>
| Gate | Empty input (probe) | Count (probe) | Real quantity | Fix |
...
Not probed: <each probe_gates.py "not probed:" line, with the fallback verdict or "unverified">
<K> gates need work, <N-K> pass
```

## Gotchas

- A CI job with `allow_failure: true` is not a gate; list it separately.
- A hook that only formats is not a gate either; it must also check.
- The audit itself follows the rule: it fails on zero gates and prints its
  count. A count the probe did not print is not written.
- The probe's copy is emptied by rule, not by knowing each gate's inputs:
  a gate whose input is a file the probe kept (a script linting itself)
  can pass there; read the `kept` list before calling it a miss.
- A repository with a CI file but no hooks (or the reverse) is audited on
  what it has; the missing layer is one line under the table, not a stop.
