# catalogue

React catalogue with a product filter. Targets: `make check` (vitest) and
`make test-e2e` (Playwright). In this fixture both targets print a fixed
result instead of starting a runner, so a run is offline: `make check`
passes and `make test-e2e` reports one failing spec and exits 1.
