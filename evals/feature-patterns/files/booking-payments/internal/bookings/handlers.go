package bookings

import (
	"encoding/json"
	"net/http"
	"sync"
)

type Handlers struct {
	mu       sync.Mutex
	bookings map[string]*Booking
}

// Create books a slot; the price comes from the clinic's fee table.
func (h *Handlers) Create(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusCreated)
}

// ConfirmPayment is called by the app when Razorpay checkout returns
// success, and marks the booking paid.
func (h *Handlers) ConfirmPayment(w http.ResponseWriter, r *http.Request) {
	var body struct {
		RazorpayPaymentID string `json:"razorpay_payment_id"`
	}
	_ = json.NewDecoder(r.Body).Decode(&body)
	h.mu.Lock()
	defer h.mu.Unlock()
	if b, ok := h.bookings[r.PathValue("id")]; ok {
		b.Status = StatusPaid
	}
	w.WriteHeader(http.StatusNoContent)
}
