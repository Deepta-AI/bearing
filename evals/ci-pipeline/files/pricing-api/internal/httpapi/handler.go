// Package httpapi serves the pricing endpoints.
package httpapi

import (
	"encoding/json"
	"net/http"
	"strconv"

	"example.com/pricing-api/internal/pricing"
)

// NewMux returns the service routes.
func NewMux() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /quote", quote)
	return mux
}

func quote(w http.ResponseWriter, r *http.Request) {
	unit, err1 := strconv.ParseInt(r.URL.Query().Get("unit_cents"), 10, 64)
	qty, err2 := strconv.ParseInt(r.URL.Query().Get("quantity"), 10, 64)
	if err1 != nil || err2 != nil || unit < 0 || qty <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "unit_cents and quantity are required"})
		return
	}
	percent := pricing.Bulk(qty)
	total, err := pricing.Apply(unit*qty, percent)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, map[string]int64{"discount_percent": percent, "total_cents": total})
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
