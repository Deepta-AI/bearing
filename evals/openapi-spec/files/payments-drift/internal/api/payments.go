package api

import (
	"encoding/json"
	"net/http"
	"sort"
	"time"
)

type Server struct{ store *Store }

func NewServer(st *Store) *Server { return &Server{store: st} }

type createPaymentRequest struct {
	AmountMinor int64  `json:"amount_minor"`
	Currency    string `json:"currency"`
	CustomerID  string `json:"customer_id"`
	Description string `json:"description,omitempty"`
}

func (s *Server) createPayment(w http.ResponseWriter, r *http.Request) {
	var req createPaymentRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeProblem(w, http.StatusBadRequest, "malformed_json", "request body is not valid JSON")
		return
	}
	if req.AmountMinor <= 0 {
		writeProblem(w, http.StatusUnprocessableEntity, "invalid_amount", "amount_minor must be positive")
		return
	}
	if req.Currency != "INR" {
		writeProblem(w, http.StatusUnprocessableEntity, "unsupported_currency", "only INR is supported")
		return
	}
	if req.CustomerID == "" {
		writeProblem(w, http.StatusUnprocessableEntity, "customer_required", "customer_id is required")
		return
	}
	s.store.mu.Lock()
	p := &Payment{
		ID: s.store.nextID("pay"), AmountMinor: req.AmountMinor, Currency: req.Currency,
		CustomerID: req.CustomerID, Description: req.Description,
		Status: "captured", CreatedAt: time.Now().UTC(),
	}
	s.store.payments[p.ID] = p
	s.store.mu.Unlock()
	writeJSON(w, http.StatusCreated, p)
}

func (s *Server) getPayment(w http.ResponseWriter, r *http.Request) {
	s.store.mu.Lock()
	p, ok := s.store.payments[r.PathValue("id")]
	s.store.mu.Unlock()
	if !ok {
		writeProblem(w, http.StatusNotFound, "not_found", "")
		return
	}
	writeJSON(w, http.StatusOK, p)
}

func (s *Server) listPayments(w http.ResponseWriter, r *http.Request) {
	s.store.mu.Lock()
	out := make([]*Payment, 0, len(s.store.payments))
	for _, p := range s.store.payments {
		out = append(out, p)
	}
	s.store.mu.Unlock()
	sort.Slice(out, func(i, j int) bool { return out[i].ID > out[j].ID })
	writeJSON(w, http.StatusOK, map[string]any{"data": out, "next_cursor": nil})
}
