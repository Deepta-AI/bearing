package checkout

import (
	"encoding/json"
	"net/http"

	"example.com/checkout/internal/notify"
	"example.com/checkout/internal/store"
)

type Handler struct {
	Store *store.Store
	SMS   *notify.SMS
	Email *notify.Email
}

type request struct {
	CartID string `json:"cart_id"`
	Phone  string `json:"phone"`
	Email  string `json:"email"`
}

func (h *Handler) Checkout(w http.ResponseWriter, r *http.Request) {
	var req request
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	order, err := h.Store.PlaceOrder(r.Context(), req.CartID)
	if err != nil {
		http.Error(w, "could not place order", http.StatusInternalServerError)
		return
	}
	// Sent inside the request: this is what made INC-231 slow checkout.
	_ = h.SMS.Send(r.Context(), req.Phone, "Order "+order.Number+" confirmed")
	_ = h.Email.Send(r.Context(), req.Email, "Your order "+order.Number, order.Summary())
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(order)
}
