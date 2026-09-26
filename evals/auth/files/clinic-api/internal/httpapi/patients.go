package httpapi

import (
	"errors"
	"net/http"
	"time"

	"example.com/clinic-api/internal/store"
)

func (h *Handlers) GetPatient(w http.ResponseWriter, r *http.Request) {
	p, err := h.Store.PatientByID(r.PathValue("id"))
	if errors.Is(err, store.ErrNotFound) {
		http.Error(w, "not found", http.StatusNotFound)
		return
	}
	writeJSON(w, p)
}

// historyEntry is one row of a patient's visit history, with the summary
// the front desk reads out when the patient calls.
type historyEntry struct {
	ID        string    `json:"id"`
	DoctorID  string    `json:"doctor_id"`
	At        time.Time `json:"at"`
	Cancelled bool      `json:"cancelled"`
	Summary   string    `json:"summary"`
}

// GetPatientHistory lists a patient's appointments for US-02-005.
func (h *Handlers) GetPatientHistory(w http.ResponseWriter, r *http.Request) {
	var out []historyEntry
	for _, a := range h.Store.AppointmentsForPatient(r.PathValue("id")) {
		out = append(out, historyEntry{ID: a.ID, DoctorID: a.DoctorID, At: a.At, Cancelled: a.Cancelled, Summary: a.Notes})
	}
	writeJSON(w, out)
}
