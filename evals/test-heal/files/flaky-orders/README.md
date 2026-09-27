# orders

Order intake for the storefront: customer registration and import,
discount pricing, and receipt notifications. Standard library only.

    make check        # go vet and the shuffled test suite
    scripts/ci-test.sh  # what CI runs

Test case ids (TC-02xx) are listed in docs/testing/test-cases.md; each
test's name or comment carries its id.

docs/testing/ci-runs.csv is an export of the last 100 CI runs: one row
per attempt, with the tests that failed in it.
