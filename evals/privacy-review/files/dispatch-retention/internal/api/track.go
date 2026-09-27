package api

import (
	"context"
	"encoding/json"
	"net/http"
)

// Delivery is what a recipient sees when tracking.
type Delivery struct {
	ID     int64  `json:"id"`
	Status string `json:"status"`
}

type TrackStore interface {
	DeliveriesForPhone(ctx context.Context, phone string) ([]Delivery, error)
}

// Track serves GET /track?phone=<recipient phone>.
func Track(s TrackStore) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		phone := r.URL.Query().Get("phone")
		if phone == "" {
			http.Error(w, "phone required", http.StatusBadRequest)
			return
		}
		ds, err := s.DeliveriesForPhone(r.Context(), phone)
		if err != nil {
			http.Error(w, "lookup failed", http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(ds)
	})
}
