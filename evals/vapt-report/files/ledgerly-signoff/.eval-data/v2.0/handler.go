package invoices

import (
	"encoding/json"
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
