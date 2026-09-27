# orders-svc

Order pricing and storage for the storefront.

## Checks

`make check` runs vet, the tests, the SQL lint and the coverage floor. CI runs
the same gates on every merge request.

Commit messages follow Conventional Commits and are checked by the
commit-msg hook in `.githooks/`.
