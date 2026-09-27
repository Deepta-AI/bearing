// Package api serves the HTTP endpoints in docs/api.md.
package api

import (
	"encoding/json"
	"errors"
	"net/http"

	"example.com/orders-api/internal/report"
	"example.com/orders-api/internal/store"
)

func NewMux(s *store.Store) *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /reports/orders", func(w http.ResponseWriter, r *http.Request) {
		status := r.URL.Query().Get("status")
		switch status {
		case "", "paid", "pending", "refunded":
		default:
			http.Error(w, "unknown status", http.StatusBadRequest)
			return
		}
		rows := report.Build(s, status)
		if rows == nil {
			rows = []report.Row{}
		}
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(rows)
	})
	mux.HandleFunc("POST /orders", func(w http.ResponseWriter, r *http.Request) {
		var o store.Order
		if err := json.NewDecoder(r.Body).Decode(&o); err != nil || o.ID == "" {
			http.Error(w, "bad order", http.StatusBadRequest)
			return
		}
		s.AddOrder(o)
		w.WriteHeader(http.StatusCreated)
	})
	mux.HandleFunc("POST /customers", func(w http.ResponseWriter, r *http.Request) {
		var c store.Customer
		if err := json.NewDecoder(r.Body).Decode(&c); err != nil || c.ID == "" {
			http.Error(w, "bad customer", http.StatusBadRequest)
			return
		}
		if err := s.AddCustomer(c); errors.Is(err, store.ErrDuplicate) {
			http.Error(w, "duplicate", http.StatusConflict)
			return
		}
		w.WriteHeader(http.StatusCreated)
	})
	mux.HandleFunc("DELETE /customers/{id}", func(w http.ResponseWriter, r *http.Request) {
		if !s.DeleteCustomer(r.PathValue("id")) {
			http.NotFound(w, r)
			return
		}
		w.WriteHeader(http.StatusNoContent)
	})
	return mux
}
