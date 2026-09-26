package orders

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"log/slog"
	"net/http"

	"example.com/shop/orders-api/internal/payments"
)

// Charger charges an order.
type Charger interface {
	Charge(orderID string, amountCents int64) (string, error)
}

// Handler serves the order routes.
type Handler struct {
	Log      *slog.Logger
	Store    *Store
	Payments Charger
}

// Register adds the routes to mux.
func (h *Handler) Register(mux *http.ServeMux) {
	mux.HandleFunc("POST /checkout", h.checkout)
	mux.HandleFunc("GET /orders/{id}", h.get)
}

type checkoutRequest struct {
	CustomerID    string `json:"customer_id"`
	CustomerEmail string `json:"customer_email"`
	AmountCents   int64  `json:"amount_cents"`
}

func (h *Handler) checkout(w http.ResponseWriter, r *http.Request) {
	var req checkoutRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil || req.AmountCents <= 0 || req.CustomerID == "" {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	id := newOrderID()
	chargeID, err := h.Payments.Charge(id, req.AmountCents)
	if errors.Is(err, payments.ErrDeclined) {
		h.Log.Info("checkout declined", slog.String("order_id", id), slog.String("customer_id", req.CustomerID))
		http.Error(w, "payment declined", http.StatusPaymentRequired)
		return
	}
	if err != nil {
		h.Log.Error("checkout failed",
			slog.String("order_id", id),
			slog.String("customer_id", req.CustomerID),
			slog.String("customer_email", req.CustomerEmail),
			slog.String("error", err.Error()),
		)
		http.Error(w, "payment provider unavailable", http.StatusBadGateway)
		return
	}
	o := Order{ID: id, CustomerID: req.CustomerID, AmountCents: req.AmountCents, ChargeID: chargeID, Status: "paid"}
	h.Store.Put(o)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(o)
}

func (h *Handler) get(w http.ResponseWriter, r *http.Request) {
	o, err := h.Store.Get(r.PathValue("id"))
	if errors.Is(err, ErrNotFound) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(o)
}

func newOrderID() string {
	b := make([]byte, 6)
	_, _ = rand.Read(b)
	return "ord_" + hex.EncodeToString(b)
}
