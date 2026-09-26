# HTTP logging middleware: Go

File: `internal/httpapi/loghttp.go`. Order in the chain: recover,
request id, this middleware, auth, routes.

## Configuration

```go
type HTTPLogConfig struct {
    Enabled  bool    // LOG_HTTP, default true in dev, false otherwise
    Bodies   bool    // LOG_HTTP_BODIES, default false
    MaxBytes int     // LOG_HTTP_MAX_BYTES, default 2048
    Sample   float64 // LOG_HTTP_SAMPLE, default 1.0
}

func HTTPLogConfigFromEnv(env string) HTTPLogConfig {
    return HTTPLogConfig{
        Enabled:  boolEnv("LOG_HTTP", env == "dev"),
        Bodies:   boolEnv("LOG_HTTP_BODIES", false),
        MaxBytes: intEnv("LOG_HTTP_MAX_BYTES", 2048),
        Sample:   floatEnv("LOG_HTTP_SAMPLE", 1.0),
    }
}
```

## Middleware

```go
var redactedHeaders = map[string]bool{"authorization": true, "cookie": true, "set-cookie": true, "x-api-key": true}

func LogHTTP(cfg HTTPLogConfig) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        if !cfg.Enabled {
            return next
        }
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // Decide once per request; a sampled-out request still logs if it fails.
            sampled := cfg.Sample >= 1 || rand.Float64() < cfg.Sample
            log := logging.FromContext(r.Context())
            start := time.Now()
            var reqBody []byte
            if cfg.Bodies && r.Body != nil {
                reqBody, _ = io.ReadAll(io.LimitReader(r.Body, int64(cfg.MaxBytes)))
                r.Body = io.NopCloser(io.MultiReader(bytes.NewReader(reqBody), r.Body))
            }
            rec := &recorder{ResponseWriter: w, status: 200, max: cfg.MaxBytes, capture: cfg.Bodies}
            next.ServeHTTP(rec, r)
            if !sampled && rec.status < 500 {
                return
            }
            // r.Pattern is set by the mux after routing; read it afterwards, and
            // fall back to the path (never r.URL.String(), which carries the query).
            route := r.Pattern
            if route == "" {
                route = r.Method + " " + r.URL.Path
            }
            log.Info("http response", "method", r.Method, "route", route, "status", rec.status,
                "duration_ms", time.Since(start).Milliseconds(), "outcome", outcome(rec.status),
                "resp_bytes", rec.size, "headers", safeHeaders(r.Header),
                "req_body", redactBody(reqBody), "body", redactBody(rec.body.Bytes()))
        })
    }
}

type recorder struct {
    http.ResponseWriter
    status, size, max int
    capture           bool
    body              bytes.Buffer
}

func (r *recorder) WriteHeader(code int) { r.status = code; r.ResponseWriter.WriteHeader(code) }
func (r *recorder) Write(b []byte) (int, error) {
    if r.capture && r.body.Len() < r.max {
        r.body.Write(b[:min(len(b), r.max-r.body.Len())])
    }
    n, err := r.ResponseWriter.Write(b)
    r.size += n
    return n, err
}

// Flush and Unwrap keep streaming handlers (http.Flusher, http.ResponseController) working behind the wrapper.
func (r *recorder) Flush() {
    if f, ok := r.ResponseWriter.(http.Flusher); ok {
        f.Flush()
    }
}
func (r *recorder) Unwrap() http.ResponseWriter { return r.ResponseWriter }

func safeHeaders(h http.Header) map[string]string {
    out := map[string]string{}
    for k := range h {
        if redactedHeaders[strings.ToLower(k)] { out[k] = "[redacted]" } else { out[k] = h.Get(k) }
    }
    return out
}
```

`r.Pattern` stays empty in this middleware when an inner middleware
replaces the request (`r.WithContext`) before the mux; then the fallback
path is logged. A path segment or query that can carry an email or token
is logged by pattern only.

`redactBody` parses JSON when it can, replaces deny-list keys with
`[redacted]`, and returns the raw prefix otherwise. `outcome` maps 2xx
and 3xx to `ok`, 4xx to `client_error`, 5xx to `server_error`.

## Flipping it at runtime

Environment only. Set `LOG_HTTP=true` on the deployment and restart the
pod; the process reads the variable once at start. Document the three
variables in `.env.example`.

## Test

One `httptest` case per toggle: disabled logs nothing, enabled logs one
line, bodies on truncates at `MaxBytes` and redacts `password`, a sampled
out request that answers 500 is still logged, and a handler that asserts
`http.Flusher` still streams through the wrapper.
