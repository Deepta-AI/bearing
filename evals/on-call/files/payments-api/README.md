# payments-api

Card payment intake for the storefront. Go 1.25, standard library only.
Runs in the `payments` namespace as the `payments-api` deployment
(deploy/k8s/deployment.yaml), three replicas, port 8080.

## Development

    make check   # go vet and go test
    make run     # listens on :8080

## Monitoring

- Metrics on `/metrics` (hand-written Prometheus text format).
- Alert rules: `monitoring/alerts/` and `deploy/prometheus/rules/`, loaded by
  `deploy/prometheus/prometheus.yml`.
- Alertmanager config: `monitoring/alertmanager.yml`.
- Alerts page the team through PagerDuty (service "payments-api").
- SLOs: `docs/observability/slos.md`. Severity scale:
  `docs/operations/severity.md`.

## Team

Owned by the payments team (see CODEOWNERS). Engineering lead: the payments
engineering manager. Service owner: the head of payments product.

| Engineer | Location | Time zone | Notes |
| --- | --- | --- | --- |
| Asha | Bengaluru | Asia/Kolkata | moves to the data platform team on 31 October 2026 |
| Karan | Bengaluru | Asia/Kolkata | |
| Meera | Bengaluru | Asia/Kolkata | |
| Tom | Lisbon | Europe/Lisbon | on leave 2 November 2026 to 15 January 2027 |
| Joana | Lisbon | Europe/Lisbon | |

Today nobody is formally on call: alerts reach whoever is online.
