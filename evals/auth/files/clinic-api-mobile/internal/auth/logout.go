package auth

import "net/http"

// Logout ends the current web session.
func (s *Sessions) Logout(w http.ResponseWriter, r *http.Request) {
	if c, err := r.Cookie("sid"); err == nil {
		s.mu.Lock()
		delete(s.byID, c.Value)
		s.mu.Unlock()
	}
	http.SetCookie(w, &http.Cookie{Name: "sid", Value: "", Path: "/", MaxAge: -1})
	w.WriteHeader(http.StatusNoContent)
}
