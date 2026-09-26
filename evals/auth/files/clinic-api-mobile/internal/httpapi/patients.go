package httpapi

import (
	"errors"
	"net/http"

	"example.com/clinic-api/internal/store"
)

func (h *Handlers) GetPatient(w http.ResponseWriter, r *http.Request) {
	p, err := h.Store.PatientByID(principal(r).ClinicID, r.PathValue("id"))
	if errors.Is(err, store.ErrNotFound) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	writeJSON(w, p)
}
