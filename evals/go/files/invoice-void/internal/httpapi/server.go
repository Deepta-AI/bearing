// Package httpapi holds the routes, handlers and JSON helpers.
package httpapi

import (
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"strconv"

	"example.com/billing-api/internal/auth"
	"example.com/billing-api/internal/invoice"
)

const maxBodyBytes = 1 << 20

// Server is the HTTP API.
type Server struct {
	Invoices *invoice.Service
	Keys     auth.KeyLookup
	Log      *slog.Logger
}

// Handler returns the routes behind the API key middleware.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /invoices", s.listInvoices)
	mux.HandleFunc("GET /invoices/{id}", s.getInvoice)
	mux.HandleFunc("POST /invoices/{id}/pay", s.payInvoice)
	return auth.Middleware(s.Keys, s.respondErr)(mux)
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v) // the status is already sent; nothing to do on a write error
}

func writeError(w http.ResponseWriter, status int, code, msg string) {
	writeJSON(w, status, map[string]any{"error": map[string]string{"code": code, "message": msg}})
}

// decodeJSON reads a size-limited body into v, rejecting unknown fields.
func decodeJSON(w http.ResponseWriter, r *http.Request, v any) error {
	dec := json.NewDecoder(http.MaxBytesReader(w, r.Body, maxBodyBytes))
	dec.DisallowUnknownFields()
	if err := dec.Decode(v); err != nil {
		return fmt.Errorf("decode body: %w", err)
	}
	return nil
}

func pathID(r *http.Request) (int64, error) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil || id <= 0 {
		return 0, fmt.Errorf("invalid invoice id %q", r.PathValue("id"))
	}
	return id, nil
}

// respondErr maps an error to a status once, and logs what the client does
// not see.
func (s *Server) respondErr(w http.ResponseWriter, r *http.Request, err error) {
	switch {
	case errors.Is(err, auth.ErrUnknownKey):
		writeError(w, http.StatusUnauthorized, "unauthorized", "missing or unknown API key")
	case errors.Is(err, invoice.ErrNotFound):
		writeError(w, http.StatusNotFound, "not_found", "no such invoice")
	case errors.Is(err, invoice.ErrInvalidState):
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
	default:
		s.Log.ErrorContext(r.Context(), "request failed", "method", r.Method, "path", r.URL.Path, "err", err)
		writeError(w, http.StatusInternalServerError, "internal", "internal error")
	}
}
