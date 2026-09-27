package auth

import (
	"crypto/pbkdf2"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/json"
	"net/http"
)

// User is a stored account.
type User struct {
	ID       string
	TenantID string
	Salt     []byte
	Hash     []byte // PBKDF2-SHA256, 600000 iterations
}

// Users looks accounts up by email.
type Users interface {
	ByEmail(email string) (User, bool)
}

// HashPassword returns the stored hash for a password and salt.
func HashPassword(password string, salt []byte) []byte {
	h, _ := pbkdf2.Key(sha256.New, password, salt, 600000, 32)
	return h
}

// LoginHandler checks email and password and sets the session cookie.
func LoginHandler(users Users, s Signer) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var body struct{ Email, Password string }
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			http.Error(w, "bad request", http.StatusBadRequest)
			return
		}
		u, ok := users.ByEmail(body.Email)
		if !ok || subtle.ConstantTimeCompare(HashPassword(body.Password, u.Salt), u.Hash) != 1 {
			http.Error(w, "invalid email or password", http.StatusUnauthorized)
			return
		}
		http.SetCookie(w, &http.Cookie{
			Name: "fd_session", Value: s.Sign(Session{UserID: u.ID, TenantID: u.TenantID}),
			Path: "/", HttpOnly: true, Secure: true, SameSite: http.SameSiteLaxMode,
		})
		w.WriteHeader(http.StatusNoContent)
	})
}
