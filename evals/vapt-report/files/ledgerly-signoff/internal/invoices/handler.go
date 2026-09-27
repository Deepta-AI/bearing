package invoices

import (
	"encoding/json"
	"fmt"
	"net/http"

	"example.com/ledgerly/internal/auth"
)

// Handler serves the invoice routes.
type Handler struct{ Store *Store }

// List handles GET /api/v1/invoices.
func (h Handler) List(w http.ResponseWriter, r *http.Request) {
	json.NewEncoder(w).Encode(h.Store.ForTenant(auth.Tenant(r.Context())))
}

// Get handles GET /api/v1/invoices/{id}.
func (h Handler) Get(w http.ResponseWriter, r *http.Request) {
	inv, ok := h.Store.Get(r.PathValue("id"))
	if !ok || inv.TenantID != auth.Tenant(r.Context()) {
		http.NotFound(w, r)
		return
	}
	json.NewEncoder(w).Encode(inv)
}

// PDF handles GET /api/v1/invoices/{id}/pdf.
func (h Handler) PDF(w http.ResponseWriter, r *http.Request) {
	inv, ok := h.Store.Get(r.PathValue("id"))
	if !ok {
		http.NotFound(w, r)
		return
	}
	w.Header().Set("Content-Type", "application/pdf")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", inv.ID+".pdf"))
	fmt.Fprintf(w, "%%PDF-1.4\n%% invoice %s for %s: %d\n", inv.ID, inv.Customer, inv.Amount)
}
