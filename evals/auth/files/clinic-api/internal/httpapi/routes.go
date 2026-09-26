package httpapi

import (
	"net/http"

	"example.com/clinic-api/internal/auth"
	"example.com/clinic-api/internal/store"
)

type Handlers struct {
	Store *store.Store
}

func Routes(st *store.Store) http.Handler {
	sessions := auth.NewSessions()
	h := &Handlers{Store: st}
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.Handle("POST /login", auth.Login(st, sessions))

	mux.Handle("GET /appointments/{id}", sessions.RequireLogin(http.HandlerFunc(h.GetAppointment)))
	mux.Handle("POST /appointments/{id}/cancel", sessions.RequireLogin(http.HandlerFunc(h.CancelAppointment)))
	mux.Handle("GET /appointments/{id}/notes", sessions.RequireLogin(http.HandlerFunc(h.GetNotes)))
	mux.Handle("GET /patients/{id}", sessions.RequireLogin(http.HandlerFunc(h.GetPatient)))
	mux.HandleFunc("GET /admin/export", h.ExportAppointments)
	mux.Handle("GET /patients/{id}/appointments", sessions.RequireLogin(http.HandlerFunc(h.GetPatientHistory)))
	return mux
}
