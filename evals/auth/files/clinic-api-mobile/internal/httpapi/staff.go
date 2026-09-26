package httpapi

import (
	"errors"
	"net/http"

	"example.com/clinic-api/internal/store"
)

// DeactivateStaff removes a staff member who has left the clinic
// (US-01-006): they can no longer sign in, and their sessions end.
func (h *Handlers) DeactivateStaff(w http.ResponseWriter, r *http.Request) {
	id := r.PathValue("id")
	if err := h.Store.Deactivate(principal(r).ClinicID, id); errors.Is(err, store.ErrNotFound) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	h.Sessions.EndUser(id)
	w.WriteHeader(http.StatusNoContent)
}
