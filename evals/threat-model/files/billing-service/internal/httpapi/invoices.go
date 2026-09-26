package httpapi

import (
	"net/http"

	"github.com/go-chi/chi/v5"
)

// InvoicePDF streams the PDF for an invoice. The session is checked by
// RequireSession in routes.go.
func (h *Handlers) InvoicePDF(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")
	inv, err := h.Store.InvoiceByID(r.Context(), id)
	if err != nil {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/pdf")
	_, _ = w.Write(inv.PDF)
}
