# health-checks: inventory and dependency classification

Read when: steps 1 and 2: finding every consumer of a health path, and deciding which dependencies are required or optional.

1. **Inventory before changing.** Find the current health handler(s)
and grep every path they serve across the repo: kubelet probes
(`livenessProbe`, `readinessProbe`, `startupProbe`) in the base AND
in every overlay, patch and per-environment values file (a kustomize
prod patch that sets its own probe path silently undoes a base fix,
and prod is usually where the incident was), load balancer
health checks (GKE `BackendConfig.healthCheck.requestPath`, AWS
target group `health_check`/`alb.ingress.kubernetes.io/healthcheck-path`,
nginx upstream checks), blackbox targets, smoke scripts, dashboards,
docs, the auth middleware's allow list. Moving or retiring a path
means updating every one of these in the same change, or keeping the
old path as an alias; never leave a consumer pointing at a 404 or at
a path that now needs a token. Also find what the old check did wrong
(a `count(*)` on a hot table, raw `err.Error()` in the body) so the
report can name it as the cause.

2. **Classify each dependency from the code, not its type.** For each
client the service builds, read the call sites: if the request path
falls back when it fails (cache miss reads the database, a quote
falls back to a list price), the check is optional: it reports
`fail` and the overall body says `degraded`, status 200. If the
service cannot serve its core requests without it, required: 503. A
dependency named only in `.env.example` or removed by an accepted ADR
gets no check, and the report says why. A probe that cannot fail
(`func Ping() error { return nil }`, a stub client) is a lie in the
readiness body: flag it and either implement a real probe or remove
it from the checks.
