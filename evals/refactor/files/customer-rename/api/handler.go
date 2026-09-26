// Package api serves the billing HTTP API.
package api

import (
	"encoding/json"
	"errors"
	"log/slog"
	"net"
	"net/http"

	"example.com/billingsvc/billing"
)

// Handler serves the API over a store.
type Handler struct {
	Store *billing.Store
	Log   *slog.Logger
}

// Routes returns the mux with every route.
func (h *Handler) Routes() *http.ServeMux {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /clients/{id}", h.getClient)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) {
		_, _ = w.Write([]byte("ok"))
	})
	return mux
}

func (h *Handler) getClient(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	h.Log.Info("get client", "client_id", id, "remote", clientIP(r))
	c, err := h.Store.Client(id)
	if errors.Is(err, billing.ErrClientNotFound) {
		writeJSON(w, http.StatusNotFound, map[string]string{"error": err.Error()})
		return
	}
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": "internal error"})
		return
	}
	writeJSON(w, http.StatusOK, c)
}

// clientIP is the address of the caller, not a billing client.
func clientIP(r *http.Request) string {
	if fwd := r.Header.Get("X-Forwarded-For"); fwd != "" {
		return fwd
	}
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}
