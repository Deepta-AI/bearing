// Package health serves liveness and readiness. Liveness (/healthz) says the
// process is up; readiness (/readyz) says every dependency the service needs
// to do useful work answers. Kubernetes restarts on the first, stops routing
// traffic on the second, so they must stay separate.
package health

import (
	"context"
	"encoding/json"
	"net/http"
	"time"
)

// Checker reports whether one dependency is usable. The store satisfies it.
type Checker interface {
	Name() string
	Ping(ctx context.Context) error
}

// Handler answers /healthz and /readyz.
type Handler struct {
	version  string
	checkers []Checker
}

// New builds a Handler with the given dependency checkers. With none, /readyz
// is ready as soon as the process serves.
func New(version string, checkers ...Checker) *Handler {
	return &Handler{version: version, checkers: checkers}
}

// Live reports that the process is up. It never touches a dependency.
func (h *Handler) Live(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]string{"status": "ok", "version": h.version})
}

// Ready reports whether every dependency is usable; 503 names the failed ones.
func (h *Handler) Ready(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	checks := map[string]string{}
	failed := 0
	for _, c := range h.checkers {
		if err := c.Ping(ctx); err != nil {
			checks[c.Name()] = "failed"
			failed++
			continue
		}
		checks[c.Name()] = "ok"
	}
	if failed > 0 {
		w.WriteHeader(http.StatusServiceUnavailable)
		_ = json.NewEncoder(w).Encode(map[string]any{"status": "not ready", "checks": checks})
		return
	}
	_ = json.NewEncoder(w).Encode(map[string]any{"status": "ok", "checks": checks})
}
