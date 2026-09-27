package httpapi

import (
	"database/sql"
	"encoding/json"
	"net/http"
)

// health reports the service as healthy when it can count the orders
// table. Used by the kubelet probes and the load balancer.
func health(db *sql.DB) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var n int64
		if err := db.QueryRowContext(r.Context(), `SELECT count(*) FROM orders`).Scan(&n); err != nil {
			http.Error(w, err.Error(), http.StatusServiceUnavailable)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"status": "ok", "orders": n})
	}
}
