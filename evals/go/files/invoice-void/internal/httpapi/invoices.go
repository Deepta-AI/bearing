package httpapi

import (
	"net/http"
	"time"

	"example.com/billing-api/internal/auth"
	"example.com/billing-api/internal/invoice"
)

type invoiceJSON struct {
	ID          int64      `json:"id"`
	Number      string     `json:"number"`
	AmountPaise int64      `json:"amount_paise"`
	Status      string     `json:"status"`
	DueOn       string     `json:"due_on"`
	CreatedAt   time.Time  `json:"created_at"`
	PaidAt      *time.Time `json:"paid_at,omitempty"`
}

func toJSON(inv invoice.Invoice) invoiceJSON {
	return invoiceJSON{
		ID:          inv.ID,
		Number:      inv.Number,
		AmountPaise: inv.AmountPaise,
		Status:      string(inv.Status),
		DueOn:       inv.DueOn.Format(time.DateOnly),
		CreatedAt:   inv.CreatedAt.UTC(),
		PaidAt:      inv.PaidAt,
	}
}

func (s *Server) listInvoices(w http.ResponseWriter, r *http.Request) {
	accountID, _ := auth.AccountID(r.Context())
	status := invoice.Status(r.URL.Query().Get("status"))
	switch status {
	case "", invoice.StatusDraft, invoice.StatusOpen, invoice.StatusPaid:
	default:
		writeError(w, http.StatusBadRequest, "invalid_request", "unknown status")
		return
	}
	invs, err := s.Invoices.List(r.Context(), accountID, status)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	items := make([]invoiceJSON, 0, len(invs))
	for _, inv := range invs {
		items = append(items, toJSON(inv))
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (s *Server) getInvoice(w http.ResponseWriter, r *http.Request) {
	accountID, _ := auth.AccountID(r.Context())
	id, err := pathID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
		return
	}
	inv, err := s.Invoices.Get(r.Context(), accountID, id)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toJSON(inv))
}

// payInvoice records a manual payment the merchant took outside the app.
func (s *Server) payInvoice(w http.ResponseWriter, r *http.Request) {
	accountID, _ := auth.AccountID(r.Context())
	id, err := pathID(r)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", err.Error())
	}
	inv, err := s.Invoices.MarkPaid(r.Context(), accountID, id)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}
	writeJSON(w, http.StatusOK, toJSON(inv))
}
