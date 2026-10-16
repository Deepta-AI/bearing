# health-checks: probe arithmetic

Read when: step 5: probe timeouts, thresholds and the shared-dependency trade-off, before editing any manifest.

5. **Probe arithmetic** (print the numbers in the report):
- readiness `timeoutSeconds` must exceed the endpoint's worst case
  (the total deadline plus margin). Kubernetes defaults
  `timeoutSeconds` to 1, so a 2 s check behind a default probe times
  out and reads as not ready on every slow ping.
- liveness points at `/healthz` only, with `failureThreshold x periodSeconds`
  long enough to ride out a GC pause or a CPU-throttled
  second (30 s or more); add a `startupProbe` when start-up is slow
  instead of a long `initialDelaySeconds`.
- the load balancer health check targets a path that exists without
  a token, and its `timeoutSec` fits the endpoint's worst case.
  Point it at `/readyz` only if you accept the next item.
- **Shared required dependency.** When every replica shares the
  required dependency (one Postgres), its outage makes every pod
  unready at once: the Service has no endpoints and the edge returns
  its own 502/503 instead of the app's error. That is usually still
  right (no restarts, fast recovery), but it is a trade-off the user
  should see: say it in the report, with the alternative (readiness
  on process state only, dependency status reported but not gating).
- Values someone tuned for a reason (a comment citing an incident,
  `INC-388: quicker restart of a wedged pod`) keep their intent: move
  the path, keep the timings unless the arithmetic above forces a
  change, and name each changed value and its incident in the report.
- Manifests owned elsewhere (`bearing-backend:infra`, a platform
  repo): print the exact values to set instead of editing.
