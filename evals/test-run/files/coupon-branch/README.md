# shop-checkout

Checkout pricing for the web shop: coupons, shipping and the order total.

## Tests

Install the tools with `pip install -r requirements-dev.txt`.

- `make test`: unit tests (`pytest`, integration tests excluded)
- `make test-integration`: tests under `tests/integration`, need Postgres in `DATABASE_URL`
- `make lint`: byte-compiles `src` and `tests`

Test cases are listed in `docs/testing/test-cases.md`; quarantined tests in
`docs/testing/quarantine.md`.
