package httpapi

import (
	"net/http"

	"example.com/clinic-api/internal/auth"
	"example.com/clinic-api/internal/store"
)

type Handlers struct {
	Store    *store.Store
	Sessions *auth.Sessions
}

// public routes skip the login check; everything else requires it.
var public = map[string]bool{"GET /healthz": true, "POST /login": true}

func Routes(st *store.Store) http.Handler {
	sessions := auth.NewSessions()
	h := &Handlers{Store: st, Sessions: sessions}
	mux := http.NewServeMux()

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusOK) })
	mux.Handle("POST /login", auth.Login(st, sessions))
	mux.HandleFunc("POST /logout", sessions.Logout)

	mux.HandleFunc("GET /appointments/{id}", h.GetAppointment)
	mux.HandleFunc("POST /appointments/{id}/cancel", allow(h.CancelAppointment, "admin", "receptionist"))
	mux.HandleFunc("GET /appointments/{id}/notes", allow(h.GetNotes, "doctor"))
	mux.HandleFunc("GET /patients/{id}", h.GetPatient)
	mux.HandleFunc("GET /admin/export", allow(h.ExportAppointments, "admin"))
	mux.HandleFunc("POST /admin/staff/{id}/deactivate", allow(h.DeactivateStaff, "admin"))
	return Authenticated(mux, sessions)
}

// Authenticated wraps the whole mux once: a new route is protected unless
// it is listed in public.
func Authenticated(mux *http.ServeMux, sessions *auth.Sessions) http.Handler {
	protected := sessions.RequireLogin(mux)
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if _, pattern := mux.Handler(r); public[pattern] {
			mux.ServeHTTP(w, r)
			return
		}
		protected.ServeHTTP(w, r)
	})
}

// allow lets only the named roles through; others get 403.
func allow(next http.HandlerFunc, roles ...string) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		p, _ := auth.FromContext(r.Context())
		for _, role := range roles {
			if p.Role == role {
				next(w, r)
				return
			}
		}
		http.Error(w, "forbidden", http.StatusForbidden)
	}
}

func principal(r *http.Request) auth.Principal {
	p, _ := auth.FromContext(r.Context())
	return p
}
