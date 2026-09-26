// Package webhooks handles the payment provider's callbacks.
package webhooks

import (
	"context"
	"encoding/json"
	"errors"
	"net/http"
	"time"

	"example.com/billing/internal/invoices"
)

// InvoiceStore is the part of the invoice store the handler needs.
type InvoiceStore interface {
	FindByExternalRef(ctx context.Context, ref string) (invoices.Invoice, error)
	MarkPaid(ctx context.Context, id int64, at time.Time) error
}

// PaidHandler handles POST /webhooks/payment-paid.
type PaidHandler struct {
	Store InvoiceStore
	Now   func() time.Time
}

type paidEvent struct {
	Reference string `json:"reference"`
}

func (h PaidHandler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	var ev paidEvent
	if err := json.NewDecoder(r.Body).Decode(&ev); err != nil || ev.Reference == "" {
		http.Error(w, "bad event", http.StatusBadRequest)
		return
	}
	inv, err := h.Store.FindByExternalRef(r.Context(), ev.Reference)
	if errors.Is(err, invoices.ErrNotFound) {
		// Acknowledge so the provider stops retrying; nothing to mark.
		w.WriteHeader(http.StatusNoContent)
		return
	}
	if err != nil {
		http.Error(w, "lookup failed", http.StatusInternalServerError)
		return
	}
	if err := h.Store.MarkPaid(r.Context(), inv.ID, h.Now()); err != nil {
		http.Error(w, "update failed", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
