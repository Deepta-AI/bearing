// Package auth checks the role carried in the session token set by the
// storefront login. Roles: customer, staff.
package auth

import (
	"net/http"
	"strings"
)

func Require(role string, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tok := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
		if tok == "" || roleOf(tok) != role {
			http.Error(w, "forbidden", http.StatusForbidden)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// roleOf reads the role from a token of the form "<role>.<session id>".
func roleOf(tok string) string {
	role, _, _ := strings.Cut(tok, ".")
	return role
}
