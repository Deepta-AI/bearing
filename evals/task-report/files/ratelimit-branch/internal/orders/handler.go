// Package orders serves the partner-facing order endpoints.
package orders

import (
	"encoding/json"
	"net/http"
)

// Order is one order as partners see it.
type Order struct {
	ID          string `json:"id"`
	Status      string `json:"status"`
	AmountPaise int64  `json:"amount_paise"`
}

// Routes returns the order endpoints backed by an in-memory sample set.
func Routes() http.Handler {
	sample := []Order{
		{ID: "ord_1001", Status: "paid", AmountPaise: 249900},
		{ID: "ord_1002", Status: "shipped", AmountPaise: 89900},
	}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/orders", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]any{"orders": sample})
	})
	mux.HandleFunc("GET /v1/orders/{id}", func(w http.ResponseWriter, r *http.Request) {
		for _, o := range sample {
			if o.ID == r.PathValue("id") {
				w.Header().Set("Content-Type", "application/json")
				_ = json.NewEncoder(w).Encode(o)
				return
			}
		}
		http.NotFound(w, r)
	})
	return mux
}
