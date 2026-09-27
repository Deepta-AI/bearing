package catalog

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"time"
)

// Readyz reports whether catalog-api can serve: the database and the
// search index must both answer.
func Readyz(db *sql.DB, search SearchIndex) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		ctx, cancel := context.WithTimeout(r.Context(), 2*time.Second)
		defer cancel()
		checks := map[string]string{"postgres": "ok", "search": "ok"}
		status := "ok"
		if err := db.PingContext(ctx); err != nil {
			checks["postgres"], status = "fail", "fail"
		}
		if err := search.Ping(ctx); err != nil {
			checks["search"], status = "fail", "fail"
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"status": status, "checks": checks})
	}
}

func Healthz(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"status":"ok"}`))
}
