# Payments repository conventions

Every repository in the group follows these. A new repository is set up to
them from its first commit; bringing one into line later has never happened.

## Registration

- A new repository is added to `repos.yaml` in the same change that creates
  it, with its kind, language, owners and, for a service or worker, its port.
- Names are lowercase with hyphens: `<thing>-api` for an HTTP service,
  `<thing>-worker` for a queue consumer, plain `<thing>` for a command-line
  tool.

## Ports

- Services and workers get a port in 8100-8199 from `repos.yaml`; it is the
  default in the code, the Dockerfile's EXPOSE and the deployment. The next
  port is the lowest one above every port in the file.
- A retired repository's port is never reused: the dashboards, alert rules
  and firewall rules are keyed on it and outlive the service.
- Command-line tools have no port.

## Go

- Go 1.25. The group's CI image is `golang:1.25-bookworm` and the build
  runners have no newer toolchain; the `go` line in go.mod is `go 1.25.0`
  until the whole group moves together (PAY-412).
- Module path: `gitlab.larkspur.example/payments/<repository>`.
- Standard library HTTP (net/http ServeMux), log/slog JSON logs.
- Health: `GET /healthz` (process up) and `GET /readyz` (dependencies up),
  on the service port.
- Postgres through pgx and sqlc, migrations with goose (ADR-0006).

## Python

- Python 3.12: the data team's job runner image is `python:3.12-slim` and
  nothing newer is available on it. `requires-python = ">=3.12"`.
- uv for environments, ruff and pytest.

## CI, review and tracking

- GitLab CI only. The group has no GitHub organisation or mirror, so a
  repository carries no `.github/` directory.
- CODEOWNERS: `* @payments/leads <owners>`, where `<owners>` is the group
  in `repos.yaml`.
- Branches and commit subjects carry the tracker key: `PAY-<n>`.

## Data handling

Bank payout exports contain beneficiary names, account numbers and IFSC
codes. A real export is never committed to any repository, not even as a
test fixture. A repository that reads them ignores `*.csv` (and `*.xlsx`)
outside `tests/fixtures/`, and its fixtures are synthetic rows made up for
the test.

Only a payments lead opens a real export, on the finance share. Everyone
else works from `docs/samples/bank_payouts_sample.csv`, which has the
bank's columns and made-up rows; nobody opens a real export on their own
machine, and no tool is tried out on one.
