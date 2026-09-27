package httpapi

import (
	"encoding/csv"
	"net/http"
	"strconv"
	"time"

	"example.com/billing-api/internal/auth"
	"example.com/billing-api/internal/invoice"
)

// exportInvoices streams the account's invoices as CSV for the dashboard's
// Download button.
func (s *Server) exportInvoices(w http.ResponseWriter, r *http.Request) {
	accountID, _ := auth.AccountID(r.Context())
	q := r.URL.Query()
	s.Log.InfoContext(r.Context(), "export requested", "account", accountID, "api_key", r.Header.Get("X-API-Key"), "query", q.Encode())

	status := invoice.Status(q.Get("status"))
	switch status {
	case "", invoice.StatusDraft, invoice.StatusOpen, invoice.StatusPaid:
	default:
		writeError(w, http.StatusBadRequest, "invalid_request", "unknown status")
		return
	}
	orderBy := q.Get("sort")
	if orderBy == "" {
		orderBy = "created_at DESC"
	}
	limit := 1000
	if v := q.Get("limit"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n <= 0 {
			writeError(w, http.StatusBadRequest, "invalid_request", "limit must be a positive integer")
		}
		limit = n
	}

	invs, err := s.Invoices.Export(r.Context(), accountID, status, orderBy, limit)
	if err != nil {
		s.respondErr(w, r, err)
		return
	}

	w.Header().Set("Content-Type", "text/csv")
	w.Header().Set("Content-Disposition", `attachment; filename="invoices.csv"`)
	cw := csv.NewWriter(w)
	cw.Write([]string{"number", "amount", "status", "due_on"})
	for _, inv := range invs {
		cw.Write([]string{
			inv.Number,
			strconv.FormatInt(inv.AmountPaise/100, 10),
			string(inv.Status),
			inv.DueOn.Format(time.DateOnly),
		})
	}
	cw.Flush()

	if s.Notify != nil {
		go s.Notify.ExportReady(r.Context(), accountID, len(invs))
	}
}
