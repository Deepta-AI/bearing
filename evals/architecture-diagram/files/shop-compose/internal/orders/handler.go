package orders

import (
	"encoding/json"
	"errors"
	"net/http"
)

type Handler struct{ Svc *Service }

type createRequest struct {
	CartID    string `json:"cart_id"`
	PaymentID string `json:"payment_id"`
}

func (h *Handler) Create(w http.ResponseWriter, r *http.Request) {
	var req createRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.CartID == "" {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	order, err := h.Svc.Place(r.Context(), req.CartID, req.PaymentID)
	switch {
	case errors.Is(err, ErrPaymentFailed):
		http.Error(w, "payment not captured", http.StatusBadGateway)
		return
	case err != nil:
		http.Error(w, "could not place order", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	_ = json.NewEncoder(w).Encode(order)
}

func (h *Handler) Get(w http.ResponseWriter, r *http.Request) {
	order, err := h.Svc.Get(r.Context(), r.PathValue("id"))
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	_ = json.NewEncoder(w).Encode(order)
}

func (h *Handler) List(w http.ResponseWriter, r *http.Request) {
	list, err := h.Svc.List(r.Context())
	if err != nil {
		http.Error(w, "could not list", http.StatusInternalServerError)
		return
	}
	_ = json.NewEncoder(w).Encode(list)
}

func (h *Handler) Refund(w http.ResponseWriter, r *http.Request) {
	order, err := h.Svc.Refund(r.Context(), r.PathValue("id"))
	switch {
	case errors.Is(err, ErrNotRefundable):
		http.Error(w, "order not refundable", http.StatusConflict)
		return
	case errors.Is(err, ErrPaymentFailed):
		http.Error(w, "refund not accepted", http.StatusBadGateway)
		return
	case err != nil:
		http.Error(w, "could not refund", http.StatusInternalServerError)
		return
	}
	_ = json.NewEncoder(w).Encode(order)
}
