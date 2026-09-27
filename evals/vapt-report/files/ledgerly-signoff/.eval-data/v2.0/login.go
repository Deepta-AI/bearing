package auth

import (
	"crypto/pbkdf2"
	"crypto/sha256"
	"crypto/subtle"
	"net/http"
)

// User is a dashboard account.
type User struct {
	ID, TenantID string
	Salt, Hash   []byte
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

// Login checks the form's email and password, starts a session through
// start and redirects to the form's next path.
func Login(users Users, start func(http.ResponseWriter, User)) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		u, ok := users.ByEmail(r.FormValue("email"))
		if !ok || subtle.ConstantTimeCompare(HashPassword(r.FormValue("password"), u.Salt), u.Hash) != 1 {
			http.Error(w, "invalid email or password", http.StatusUnauthorized)
			return
		}
		start(w, u)
		next := r.FormValue("next")
		if next == "" {
			next = "/"
		}
		http.Redirect(w, r, next, http.StatusSeeOther)
	})
}
