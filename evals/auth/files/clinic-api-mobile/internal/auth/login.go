package auth

import (
	"encoding/json"
	"net/http"

	"example.com/clinic-api/internal/store"
)

// Login checks the email and password and sets the sid cookie.
func Login(st *store.Store, sessions *Sessions) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Email    string `json:"email"`
			Password string `json:"password"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		u, ok := st.CheckPassword(body.Email, body.Password)
		if !ok {
			http.Error(w, "invalid email or password", http.StatusUnauthorized)
			return
		}
		sid := sessions.Create(Principal{UserID: u.ID, ClinicID: u.ClinicID, Role: u.Role})
		http.SetCookie(w, &http.Cookie{Name: "sid", Value: sid, Path: "/", HttpOnly: true, SameSite: http.SameSiteLaxMode})
		w.WriteHeader(http.StatusNoContent)
	}
}
