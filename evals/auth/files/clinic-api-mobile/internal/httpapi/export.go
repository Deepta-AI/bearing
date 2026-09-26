package httpapi

import (
	"encoding/csv"
	"net/http"
	"time"
)

// ExportAppointments writes a clinic's appointments as CSV for the
// monthly review.
func (h *Handlers) ExportAppointments(w http.ResponseWriter, r *http.Request) {
	clinicID := principal(r).ClinicID
	w.Header().Set("Content-Type", "text/csv")
	cw := csv.NewWriter(w)
	_ = cw.Write([]string{"id", "patient_id", "doctor_id", "at", "cancelled"})
	for _, a := range h.Store.AppointmentsForClinic(clinicID) {
		c := "no"
		if a.Cancelled {
			c = "yes"
		}
		_ = cw.Write([]string{a.ID, a.PatientID, a.DoctorID, a.At.Format(time.RFC3339), c})
	}
	cw.Flush()
}
