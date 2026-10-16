# dependency-audit: the Go audit and the supply-chain risk auditor

Read when you audit a Go stack (step 2) or run the supply-chain-risk-auditor skill.

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
