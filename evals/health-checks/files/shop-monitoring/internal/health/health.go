// Package health serves /healthz and /readyz for checkout-api.
package health

import (
	"context"
	"encoding/json"
	"net/http"
	"sync"
	"time"
)

type Check struct {
	Name     string
	Required bool
	Timeout  time.Duration
	Probe    func(ctx context.Context) error
}

type result struct {
	Status     string `json:"status"`
	DurationMS int64  `json:"duration_ms"`
	Error      string `json:"error,omitempty"`
}

type Handler struct {
	Version string
	Checks  []Check
}

func (h *Handler) Healthz(w http.ResponseWriter, _ *http.Request) {
	write(w, http.StatusOK, map[string]string{"status": "ok", "version": h.Version})
}

func (h *Handler) Readyz(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	status := "ok"
	checks := map[string]result{}
	var mu sync.Mutex
	var wg sync.WaitGroup
	for _, c := range h.Checks {
		wg.Add(1)
		go func(c Check) {
			defer wg.Done()
			cctx, ccancel := context.WithTimeout(ctx, c.Timeout)
			defer ccancel()
			start := time.Now()
			err := c.Probe(cctx)
			res := result{Status: "ok", DurationMS: time.Since(start).Milliseconds()}
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				res.Status, res.Error = "fail", err.Error()
				if c.Required {
					status = "fail"
				} else if status == "ok" {
					status = "degraded"
				}
			}
			checks[c.Name] = res
		}(c)
	}
	wg.Wait()
	code := http.StatusOK
	if status == "fail" {
		code = http.StatusServiceUnavailable
	}
	write(w, code, map[string]any{"status": status, "version": h.Version, "checks": checks})
}

func write(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
