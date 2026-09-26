# orders-web

The customer order history pages and the small API behind them.

- `make dev` runs the web app and the API locally on ports 3000 and 8080.
- `make check` runs lint and the tests.
- The GitLab pipeline deploys develop to qa and tags to prod; the
  engineer on the release rotation presses the deploy button.

The service answers `/healthz`, `/readyz` and `/version` (JSON with a
`commit` field).
