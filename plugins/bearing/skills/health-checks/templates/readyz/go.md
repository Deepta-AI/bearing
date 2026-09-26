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
    total   time.Duration
}

func New(version string, checks ...Check) *Handler {
    return &Handler{version: version, checks: checks, total: 5 * time.Second}
}

func (h *Handler) Healthz(w http.ResponseWriter, r *http.Request) {
    writeJSON(w, http.StatusOK, map[string]string{"status": "ok", "version": h.version})
}

func (h *Handler) Readyz(w http.ResponseWriter, r *http.Request) {
    ctx, cancel := context.WithTimeout(r.Context(), h.total)
    defer cancel()
    rep := report{Status: OK, Version: h.version, Checks: make(map[string]result, len(h.checks))}
    var mu sync.Mutex
    var wg sync.WaitGroup
    for _, c := range h.checks {
        wg.Add(1)
        go func(c Check) {
            defer wg.Done()
            cctx, ccancel := context.WithTimeout(ctx, c.Timeout)
            defer ccancel()
            start := time.Now()
            err := c.Probe(cctx)
            res := result{Status: OK, DurationMS: time.Since(start).Milliseconds()}
            if err != nil {
                res.Status, res.Error = Fail, short(err)
            }
            mu.Lock()
            rep.Checks[c.Name] = res
            if err != nil {
                if c.Required {
                    rep.Status = Fail
                } else if rep.Status == OK {
                    rep.Status = Degraded
                }
            }
            mu.Unlock()
        }(c)
    }
    wg.Wait()
    code := http.StatusOK
    if rep.Status == Fail {
        code = http.StatusServiceUnavailable
    }
    writeJSON(w, code, rep)
}
```

## Probes

```go
health.Check{Name: "postgres", Required: true, Timeout: 2 * time.Second,
    Probe: func(ctx context.Context) error { return pool.Ping(ctx) }},
health.Check{Name: "redis", Required: false, Timeout: time.Second,
    Probe: func(ctx context.Context) error { return rdb.Ping(ctx).Err() }},
health.Check{Name: "nats", Required: true, Timeout: time.Second,
    Probe: func(ctx context.Context) error { if nc.Status() != nats.CONNECTED { return errors.New("not connected") }; return nil }},
health.Check{Name: "payments-api", Required: true, Timeout: 2 * time.Second,
    Probe: func(ctx context.Context) error { return httpOK(ctx, client, paymentsURL+"/healthz") }},
```

`short(err)` returns the first 120 characters of the error with any
host, user or password removed. `httpOK` does a GET and returns an error
for anything but 200.

## Kubernetes probe values

```yaml
livenessProbe:  { httpGet: { path: /healthz, port: http }, periodSeconds: 10, failureThreshold: 3 }
readinessProbe: { httpGet: { path: /readyz,  port: http }, periodSeconds: 10, timeoutSeconds: 6, failureThreshold: 3 }
startupProbe:   { httpGet: { path: /healthz, port: http }, periodSeconds: 5,  failureThreshold: 30 }
```

## Test

`httptest` with fake probes: all ok gives 200 and `ok`; an optional
failure gives 200 and `degraded`; a required failure gives 503 with the
check named; a probe that sleeps past its timeout reports `fail` with
`context deadline exceeded` and the whole call returns under `total`.
