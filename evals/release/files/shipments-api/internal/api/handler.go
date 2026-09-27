// Package api serves the shipments HTTP API.
package api

import (
	"encoding/json"
	"net/http"
	"strconv"

	"example.com/shipments-api/internal/store"
	"example.com/shipments-api/internal/version"
)

type Store interface {
	List(status string, limit int) []store.Shipment
	Get(id string) (store.Shipment, bool)
}

const defaultLimit = 50

func NewHandler(s Store) http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /v1/shipments", func(w http.ResponseWriter, r *http.Request) {
		limit := defaultLimit
		if v := r.URL.Query().Get("limit"); v != "" {
			n, err := strconv.Atoi(v)
			if err != nil || n < 1 {
				http.Error(w, "limit must be a positive integer", http.StatusBadRequest)
				return
			}
			limit = n
		}
		writeJSON(w, map[string]any{"shipments": s.List(r.URL.Query().Get("status"), limit)})
	})
	mux.HandleFunc("GET /v1/shipments/{id}", func(w http.ResponseWriter, r *http.Request) {
		sh, ok := s.Get(r.PathValue("id"))
		if !ok {
			http.Error(w, "shipment not found", http.StatusNotFound)
			return
		}
		writeJSON(w, sh)
	})
	mux.HandleFunc("GET /version", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, map[string]string{"version": version.Version})
	})
	return mux
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}
