# Readiness checker: Go

File: `internal/health/health.go`. Wired in `main.go` with one `Check`
per dependency. Routes `GET /healthz` and `GET /readyz` are registered
before auth.

```go
package health

type Status string

const (
    OK       Status = "ok"
    Degraded Status = "degraded"
    Fail     Status = "fail"
)

// Check probes one dependency. Required=false means a failure degrades
// instead of failing readiness (a cache, a non-critical downstream).
type Check struct {
    Name     string
    Required bool
    Timeout  time.Duration
    Probe    func(ctx context.Context) error
}

type result struct {
    Status     Status `json:"status"`
    DurationMS int64  `json:"duration_ms"`
    Error      string `json:"error,omitempty"`
}

type report struct {
    Status  Status            `json:"status"`
    Version string            `json:"version"`
    Checks  map[string]result `json:"checks"`
}

type Handler struct {
    version string
    checks  []Check
    total   time.Duration // longer than every Check.Timeout; the probe timeoutSeconds exceeds it
    log     *slog.Logger
}

func New(log *slog.Logger, version string, total time.Duration, checks ...Check) *Handler {
    return &Handler{version: version, checks: checks, total: total, log: log}
}

func (h *Handler) Healthz(w http.ResponseWriter, r *http.Request) {
    writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "version": h.version})
}

func (h *Handler) Readyz(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), h.total)
    defer cancel()
    type named struct {
        name string
        res  result
    }
    out := make(chan named, len(h.checks)) // buffered: a late probe never blocks
    for _, c := range h.checks {
        go func(c Check) {
            cctx, ccancel := context.WithTimeout(ctx, c.Timeout)
            defer ccancel()
            start := time.Now()
            err := c.Probe(cctx)
            res := result{Status: OK, DurationMS: time.Since(start).Milliseconds()}
            if err != nil {
                res.Status, res.Error = Fail, reason(cctx, err)
                h.log.Warn("readiness check failed", "check", c.Name, "err", err) // full error to the log only
            }
            out <- named{c.Name, res}
        }(c)
    }
    rep := report{Status: OK, Version: h.version, Checks: make(map[string]result, len(h.checks))}
collect:
    for range h.checks {
        select {
        case n := <-out:
            rep.Checks[n.name] = n.res
        case <-ctx.Done(): // a probe that ignores its context cannot hold the response
            break collect
        }
    }
    for _, c := range h.checks {
        res, ok := rep.Checks[c.Name]
        if !ok {
            res = result{Status: Fail, DurationMS: h.total.Milliseconds(), Error: "timeout"}
            rep.Checks[c.Name] = res
        }
        if res.Status == Fail {
            if c.Required {
                rep.Status = Fail
            } else if rep.Status == OK {
                rep.Status = Degraded
            }
        }
    }
    code := http.StatusOK
    if rep.Status == Fail {
        code = http.StatusServiceUnavailable
    }
    writeJSON(w, code, rep)
}

// reason is the only error text the unauthenticated body carries: a fixed
// word, never err.Error(), which carries hosts, users and database names.
func reason(ctx context.Context, err error) string {
    if ctx.Err() != nil || errors.Is(err, context.DeadlineExceeded) {
        return "timeout"
    }
    return "unavailable"
}
```

## Probes

Examples only: add a check for each dependency the code really uses,
`Required` from what the call sites do when it fails (Step 2).

```go
// probeDB is a second *sql.DB on the same DSN with SetMaxOpenConns(1):
// db.PingContext on the request pool waits for a free connection, so a
// saturated pool at peak would mark every pod unready at once.
health.Check{Name: "postgres", Required: true, Timeout: time.Second,
    Probe: func(ctx context.Context) error { return probeDB.PingContext(ctx) }},
health.Check{Name: "redis", Required: false, Timeout: 500 * time.Millisecond, // reads fall back to Postgres
    Probe: func(ctx context.Context) error { return cache.Ping(ctx) }},
health.Check{Name: "pricing-api", Required: false, Timeout: time.Second, // price falls back to list price
    Probe: func(ctx context.Context) error { return httpOK(ctx, client, pricingURL+"/healthz") }},
```

`httpOK` does a GET and returns an error for anything but 2xx; it never
calls the downstream's `/readyz` or a business endpoint.

## Kubernetes probe values

```yaml
livenessProbe:  { httpGet: { path: /healthz, port: http }, periodSeconds: 10, timeoutSeconds: 2, failureThreshold: 3 }
readinessProbe: { httpGet: { path: /readyz,  port: http }, periodSeconds: 10, timeoutSeconds: 3, failureThreshold: 3 }  # total 2 s
startupProbe:   { httpGet: { path: /healthz, port: http }, periodSeconds: 5,  failureThreshold: 30 }
```

## Test

`httptest` with fake probes: all ok gives 200 and `ok`; an optional
failure gives 200 and `degraded`; a required failure gives 503 with the
check named; a probe that blocks and ignores its context
(`time.Sleep(10*time.Second)`) is reported `timeout` and the call returns
within `total` plus a small margin; a probe whose error text holds a DSN
leaves no host or user in the body; with the request pool held full
(`SetMaxOpenConns(1)` and one connection checked out) readiness still
answers 200; `/healthz` answers 200 with every
check failing; both paths answer without a token.
