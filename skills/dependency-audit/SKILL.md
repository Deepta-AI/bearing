---
name: dependency-audit
description: 'Audits dependencies for vulnerabilities and outdated versions, applies approved patch and minor upgrades with tests, keeps Renovate current. Use when asked to "audit dependencies", "update the packages" or "bump deps".'
argument-hint: "[--audit-only] [--apply patch|minor] [--renovate]"
allowed-tools: Read, Write, Edit, Grep, Glob, Skill, Bash(make check:*), Bash(make vuln:*), Bash(make go:*), Bash(git diff:*), Bash(git status:*), Bash(git ls-files:*), Bash(git branch:*), Bash(git symbolic-ref:*), Bash(mktemp -d:*), Bash(git checkout -- :*), Bash(pnpm:*), Bash(go:*), Bash(govulncheck:*), Bash(uv:*), Bash(./gradlew dependencyUpdates:*), Bash(swift package:*), Bash(terraform:*), Bash(mkdir -p .scratch), Bash(gh auth status:*), Bash(python3 -c:*), Bash(python3 *skills/dependency-audit/scripts/supply-chain.py*)
---

# dependency-audit

An upgrade is a change like any other: one group, one gate run, one
commit. The plan is ordered by what can hurt, not by what is newest.

## Inputs

- manifests: `go.mod`, `pyproject.toml`, `package.json`,
  `build.gradle.kts`, `Package.swift`, `*.tf`, searched to depth 3; none
  found: stop with "0 manifests found; name the directory that holds
  one".
- audit tools: the stack's, as in step 2; a missing tool (`govulncheck`,
  `pip-audit`, the Gradle versions plugin) is reported with its install
  command, and that stack's audit is done by reading the manifest and
  lockfile against the registry by hand, marked "manual" in the table.
- gate: `make check` when the Makefile has a `check` target; if absent,
  the stack's native command (`go vet ./... && go test ./...`, `pnpm
  test`, `uv run pytest`, `./gradlew test`, `swift test`) and the report
  says the gate is improvised.
- task id for commit messages: the branch name; if absent, the messages
  are printed without `[ID]` and the report says so.
- read-only: `--audit-only`, or a request that says not to change
  anything ("don't change anything", "just tell me", "before we
  decide"). Read-only writes nothing into the repository, not even a
  gitignored `.scratch/` file, and nothing into the user's home: the plan
  is printed, not written, and every Go command runs with a throwaway
  `GOMODCACHE` (below).
- `.scratch/`: created with `mkdir -p` only when files are applied; if
  `.gitignore` exists and lacks the line, say so.
- the repository's own settings for its package tools: a Makefile target
  (`make vuln`, `make go ARGS=...`), `.envrc`, `GOPROXY`, `GOPRIVATE`,
  `GONOSUMDB`, `GOFLAGS`, `.npmrc`, `pip.conf` or `uv` index settings.
  Every audit and upgrade command runs with them; a private or offline
  mirror is never bypassed for the public registry.
- holds: ADRs (`docs/adr`, `docs/decisions`), the README's dependency
  section, `renovate.json` `ignoreDeps` or `allowedVersions`, and pin
  comments in the manifest. Read before the plan; a held package is
  never bumped past its hold.
- Renovate config: only with `--renovate` or when the request asks for
  it; the repository's `renovate.json` when present, else this skill's
  own `templates/renovate.json` fitted to the repository (step 7).

## Steps

1. Detect the stacks as in Inputs. A repo can hold more than one; each
   gets its own table.
2. Audit, per stack, and record every command's output:
   - react-web, react-native: `pnpm audit --json` and `pnpm outdated
     --format json`.
   - go-api: `govulncheck ./...` and `go list -m -u -json all`, with the
     repository's settings. The vulnerability database is the one the
     repository uses: its `make vuln` target, `GOVULNDB`, or a mirrored
     database in the tree (`-db file://<absolute path>`). The public
     database (vuln.go.dev) has no entries for private modules (the
     `GOPRIVATE` or `GONOSUMDB` paths), so a clean public scan says
     nothing about them: report them "not covered" unless a mirrored or
     internal database was used. Quote the database's sync date
     (`index/db.json` `modified`); advisories after it are not covered.
     `go list -m -u` never reports a new major, because `/v2` and up is
     a different module path: for each module ask for the next path too
     (`go list -m -versions <path>/v<N+1>`, or the mirror's
     `<path>/v<N+1>/@v/list`) and list what exists as a major.
     `go get`, `go list -m -u` and `govulncheck` download into the module
     cache in the user's home; run them with
     `GOMODCACHE=$(mktemp -d)` (removed afterwards with
     `go clean -modcache` under the same variable) so nothing outside
     the repository changes, and say so. `go get` in read-only mode runs
     only in a copy of the repository outside it, never in the tree.
   - python-api: `uv run pip-audit --format json` and `uv tree
     --outdated`.
   - android: `./gradlew dependencyUpdates -DoutputFormatter=json`
     (needs the versions plugin; if absent, report it and read
     `gradle/libs.versions.toml` by hand).
   - ios: `swift package show-dependencies --format json` against the
     resolved file; vulnerabilities from the GitHub advisory of each
     package (say which were checked by hand).
   - infra: `terraform providers` and `terraform init -upgrade=false
     -backend=false` to read the lock; compare with the registry
     versions in the constraint.
   Zero packages audited in a detected stack is a failure, not a clean
   result.
   Then the supply-chain checks no audit tool makes, for every stack at
   once:
   `python3 "${CLAUDE_PLUGIN_ROOT}/skills/dependency-audit/scripts/supply-chain.py" --root .`
   It checks that every manifest has its lockfile and that git tracks
   it, and lists every production dependency (the `dependencies`
   closure, never `devDependencies`) that runs a `preinstall`,
   `install` or `postinstall` script, reading the installed
   `node_modules`. Native builds (`binding.gyp`, a bare `node-gyp
   rebuild`) are listed as expected. Its count line goes in the report
   verbatim. Severity: an unexpected install script or a missing
   lockfile in an application is HIGH; an untracked lockfile is MEDIUM;
   a library that leaves its lockfile out on purpose is not a finding,
   and the report says which manifest was judged a library. A
   `package.json` with no `node_modules` is "not checked", never clean.
   Then the risk the audit tools do not measure, for npm, PyPI and Go
   manifests: when the `supply-chain-risk-auditor` skill is installed,
   load it through the Skill tool and follow its workflow, writing its
   output to `.scratch/supply-chain-findings.json` and
   `.scratch/supply-chain-report.md`. It measures, from the registries
   and advisory databases, version-matched advisories across the
   lockfile tree, abandoned or archived upstreams, npm publisher
   concentration and install-time scripts, and it marks what it could
   not assess. It never installs or upgrades anything, so this skill
   still classifies, plans, applies and gates. Its advisories join the
   `vulnerable` rows; an abandoned or archived dependency goes in the
   replace group, judged by the engineer, never swapped here. It does
   not read `pnpm-lock.yaml`, so for a pnpm project its transitive sweep
   falls back to the pins and the report says so. Quote the assessed
   counts from its coverage table verbatim; its unassessable rows are
   not findings and not clean. It queries public registries and
   advisory databases over the network: when the host is offline, or
   every dependency is private (resolved from an internal mirror or
   `GOPRIVATE` path the public registries do not know), do not start it;
   write "supply-chain-risk-auditor: not run (offline)" or "(private
   modules only)". When the skill is not installed, or the
   stack is android, ios or infra, write "supply-chain-risk-auditor: not
   run (<reason>)" and continue: the audit tools and `supply-chain.py`
   above still stand.
3. Classify each finding: `vulnerable` (with the advisory id, the fixed
   version, and whether the vulnerable symbol is reached from the code,
   with the call path), `patch`, `minor`, `major`, `held` (with the ADR
   or pin that holds it). A vulnerable package is the top of the plan
   whatever its bump size. Two findings that combine (an auth bypass in
   front of a route another advisory hits) are ranked together and the
   report says why. A minor that breaks the build is not a safe minor:
   try it, and if it needs a code change, offer the newest version that
   does not (a patch release that carries the fix) and name the change.
4. Write the plan to `.scratch/deps-plan.md` (read-only: print it
   instead): groups in order
   (vulnerable, patch, minor, major, held, then replace for abandoned or
   archived upstreams), each row with current version,
   target, and the changelog or release-notes link to read. Majors get
   a line each on what the release notes say breaks. Print the plan and
   stop when read-only.
5. Ask for approval per group (patch, minor) and per package (major).
   Apply only what was approved, with the stack's own command: `pnpm up
   <pkg>@<ver>`, `go get <mod>@<ver>` then `go mod tidy`, `uv lock
   --upgrade-package <pkg>`, edit `libs.versions.toml`, edit
   `Package.swift` and `swift package resolve`, edit the `~>` constraint
   and `terraform init -upgrade -backend=false`.
   Before the first group, when the lockfile is not tracked by git
   (`git ls-files --error-unmatch <lockfile>` fails), `git checkout`
   cannot restore it: copy it to a `mktemp -d` directory outside the
   repository, and remove that copy when the run ends.
6. Run the gate after each group. A failing group is reverted with
   `git checkout -- <manifest> <lockfile>` (the saved copy for an
   untracked lockfile), the failure is recorded in the plan, and the
   next group proceeds. Never leave a red tree. At the end the working
   tree holds only the approved upgrades and the plan: no backups, no
   trial files.
7. Renovate, only with `--renovate` or when the request asks for it;
   otherwise skip and say "Renovate: not requested". Write or refresh
   `renovate.json` from `templates/renovate.json`, keeping any
   `packageRules` the repo added, and fit it to the repository:
   the template names no `baseBranches`, so Renovate uses the default
   branch; add one only for a branch that exists (`git branch -a`),
   never an assumed `develop`; the manager blocks and `packageRules`
   are only those of the detected stacks (drop terraform, expo, android and the rest when
   the repo has none), every hold from Inputs becomes an
   `allowedVersions` rule naming its ADR, and a repository whose modules
   come from an offline or internal mirror gets a note that Renovate
   needs the same registry (`hostRules` or `registryUrls`) to see them.
   `python3 -c "import json; json.load(open('renovate.json'))"`.
8. Print the contract. Commits are the engineer's; print the suggested
   messages (`build(deps): bump <pkg> to <ver> [<ID>]`).

## Output contract

```
## Dependencies: <repo> (<stacks>)
| Stack | Audited | Vulnerable | Patch | Minor | Major | Tool |
| ... | N | N | N | N | N | <tool> or manual |
Supply chain: <supply-chain.py count line, verbatim>
Risk: <supply-chain-risk-auditor coverage counts, verbatim> | not run (<reason>)
Vulnerable: <module> <version>: <advisory id> (<reached from path | not reached>), fixed in <ver> | no fix (<mitigation>), one line each
Not covered: <modules no advisory database used knows> | none; database synced <date>
Plan: .scratch/deps-plan.md (N groups) | printed (read-only)
Applied: <group>: N packages, gate passed | reverted (<target>)
Skipped: N majors awaiting a yes (including /vN module paths); N held (ADR); N vulnerable without a fix (listed)
Lockfile: tracked | untracked (in .gitignore: its changes are not in the diff)
Renovate: renovate.json written | refreshed | unchanged | not requested
Gate: make check | <native command> (improvised)
```

## Gotchas

- Never add a dependency. A fix that needs a new package is a finding
  for the engineer, not an action.
- A vulnerable package with no fixed version is reported with the
  advisory, its reachability if the tool says (govulncheck does), and
  a suggested mitigation; it is not silently left out.
- `pnpm audit` reports transitive packages; the fix is often an
  `overrides` entry, which needs a comment naming the advisory and a
  removal date, and is proposed, not applied.
- Go's `go get -u ./...` and pnpm's `up --latest` upgrade everything at
  once; neither is used here.
- Lockfiles are part of the change; a manifest bump without its lock
  is a broken commit. A lockfile that is in `.gitignore` gives every
  clone and every CI run a different tree; the supply-chain check
  reports it as untracked.
- An install script runs with the developer's and the CI runner's
  credentials the moment someone installs. A new one in a production
  dependency is read before the upgrade is approved; pnpm 10 only runs
  scripts listed in `onlyBuiltDependencies`, which is where an approved
  one is named.
- Terraform provider majors change resource schemas; the plan output
  from `make plan` is the test, and a person reads it before approval.
- A manual audit is only as current as the advisory pages read that
  day; the table says "manual" so nobody mistakes it for a scan.
- A trial upgrade or a test that reproduces an exploit runs in a copy of
  the repository outside it (`mktemp -d`), with a throwaway module cache;
  the reproducing test is offered as the regression test, not added to
  the tree unless the upgrade was asked for.
