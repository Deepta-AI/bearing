package refunds

import (
	"encoding/json"
	"errors"
	"net/http"
)

type refundRequest struct {
	Amount int64 `json:"amount"`
}

type refundResponse struct {
	PaymentID string `json:"payment_id"`
	Refunded  int64  `json:"refunded"`
}

// Handler serves POST /payments/{id}/refunds.
type Handler struct {
	store Store
}

func NewHandler(s Store) *Handler { return &Handler{store: s} }

func (h *Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var req refundRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.Amount <= 0 {
		http.Error(w, "amount must be a positive number of paise", http.StatusBadRequest)
		return
	}
	id := r.PathValue("id")
	p, err := h.store.AddRefund(id, req.Amount)
	if errors.Is(err, ErrNotFound) {
		http.Error(w, "payment not found", http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(refundResponse{PaymentID: p.ID, Refunded: p.Refunded})
}
