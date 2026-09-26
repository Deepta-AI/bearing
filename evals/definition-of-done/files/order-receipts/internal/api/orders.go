// Package api holds the HTTP handlers.
package api

import (
	"context"
	"encoding/csv"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"
	"strconv"

	"example.com/orders/internal/analytics"
	"example.com/orders/internal/store"
)

// Store is what the handlers need from the order store.
type Store interface {
	Get(ctx context.Context, id string) (store.Order, error)
	List(ctx context.Context) ([]store.Order, error)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

// writeStoreError maps a store error to the response CONTRIBUTING.md names.
func writeStoreError(w http.ResponseWriter, r *http.Request, err error) {
	if errors.Is(err, store.ErrNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "not_found"})
		return
	}
	slog.ErrorContext(r.Context(), "store", "request_id", RequestIDFrom(r.Context()), "err", err)
	writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal"})
}

// GetOrder serves GET /v1/orders/{id}.
func GetOrder(s Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		o, err := s.Get(r.Context(), r.PathValue("id"))
		if err != nil {
			writeStoreError(w, r, err)
			return
		}
		analytics.Track(r.Context(), "order_viewed", map[string]string{"order_id": o.ID, "status": o.Status})
		writeJSON(w, http.StatusOK, o)
	}
}

// ExportOrders serves GET /v1/orders/export/{format} for the support desk.
func ExportOrders(s Store) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		if r.PathValue("format") != "csv" {
			writeStoreError(w, r, store.ErrNotFound)
			return
		}
		orders, err := s.List(r.Context())
		if err != nil {
			writeStoreError(w, r, err)
			return
		}
		w.Header().Set("Content-Type", "text/csv")
		cw := csv.NewWriter(w)
		_ = cw.Write([]string{"id", "customer_id", "status", "total_paise"})
		for _, o := range orders {
			_ = cw.Write([]string{o.ID, o.CustomerID, o.Status, strconv.FormatInt(o.TotalPaise, 10)})
		}
		cw.Flush()
	}
}

// Healthz serves GET /healthz.
func Healthz(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}
