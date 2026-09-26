package httpapi

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
)

// RefundInvoice refunds part or all of a paid invoice through Razorpay.
// Any logged-in staff member can call it.
func (h *Handlers) RefundInvoice(w http.ResponseWriter, r *http.Request) {
	var req struct {
		Amount int64 `json:"amount"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad body", http.StatusBadRequest)
		return
	}
	id := chi.URLParam(r, "id")
	if err := h.Payments.Refund(r.Context(), id, req.Amount); err != nil {
		http.Error(w, err.Error(), http.StatusBadGateway)
		return
	}
	w.WriteHeader(http.StatusAccepted)
}
