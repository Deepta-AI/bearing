package appointments

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"
)

type Handler struct{ Store *Store }

type createRequest struct {
	ClinicID  int64     `json:"clinic_id"`
	PatientID int64     `json:"patient_id"`
	StartsAt  time.Time `json:"starts_at"`
	Reason    string    `json:"reason"`
}

func (h *Handler) Routes(mux *http.ServeMux) {
	mux.HandleFunc("POST /appointments", h.create)
	mux.HandleFunc("POST /appointments/{id}/reschedule", h.reschedule)
	mux.HandleFunc("POST /appointments/{id}/cancel", h.cancel)
}

func (h *Handler) create(w http.ResponseWriter, r *http.Request) {
	var req createRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	a := &Appointment{ClinicID: req.ClinicID, PatientID: req.PatientID, StartsAt: req.StartsAt, Reason: req.Reason}
	if err := h.Store.Create(r.Context(), a); err != nil {
		http.Error(w, "could not book", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(map[string]int64{"id": a.ID})
}

func (h *Handler) reschedule(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.Error(w, "bad id", http.StatusBadRequest)
		return
	}
	var body struct {
		StartsAt time.Time `json:"starts_at"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}
	if err := h.Store.Reschedule(r.Context(), id, body.StartsAt); err != nil {
		http.Error(w, "could not reschedule", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (h *Handler) cancel(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.Error(w, "bad id", http.StatusBadRequest)
		return
	}
	if err := h.Store.Cancel(r.Context(), id); err != nil {
		http.Error(w, "could not cancel", http.StatusInternalServerError)
		return
	}
	w.WriteHeader(http.StatusNoContent)
}
