package httpapi

import (
	"encoding/json"
	"errors"
	"net/http"

	"example.com/clinic-api/internal/store"
)

func (h *Handlers) GetAppointment(w http.ResponseWriter, r *http.Request) {
	a, err := h.Store.AppointmentByID(principal(r).ClinicID, r.PathValue("id"))
	if errors.Is(err, store.ErrNotFound) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	writeJSON(w, a)
}

func (h *Handlers) CancelAppointment(w http.ResponseWriter, r *http.Request) {
	if err := h.Store.CancelAppointment(principal(r).ClinicID, r.PathValue("id")); errors.Is(err, store.ErrNotFound) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handlers) GetNotes(w http.ResponseWriter, r *http.Request) {
	a, err := h.Store.AppointmentByID(principal(r).ClinicID, r.PathValue("id"))
	if errors.Is(err, store.ErrNotFound) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	writeJSON(w, map[string]string{"appointment_id": a.ID, "notes": a.Notes})
}

func writeJSON(w http.ResponseWriter, v any) {
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(v)
}
