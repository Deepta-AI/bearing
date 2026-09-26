package httpapi

import (
	"encoding/csv"
	"net/http"
)

// ImportCustomersCSV creates one customer per row: name, email, phone.
func (h *Handlers) ImportCustomersCSV(w http.ResponseWriter, r *http.Request) {
	rows, err := csv.NewReader(r.Body).ReadAll()
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	for _, row := range rows {
		_ = h.Store.CreateCustomer(r.Context(), h.TenantID(r), row[0], row[1], row[2])
	}
	w.WriteHeader(http.StatusNoContent)
}
