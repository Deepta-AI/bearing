package auth

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"mods.example.com/jwtkit"
)

var key = []byte("test-key")

func call(t *testing.T, h http.Handler, token string) int {
	t.Helper()
	req := httptest.NewRequest("GET", "/invoices", nil)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, req)
	return rec.Code
}

func TestMiddleware(t *testing.T) {
	ok := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	good, err := jwtkit.Sign(jwtkit.Claims{"sub": "u1", "role": "clerk"}, key)
	if err != nil {
		t.Fatal(err)
	}
	forged, _ := jwtkit.Sign(jwtkit.Claims{"sub": "u1", "role": "admin"}, []byte("other-key"))

	h := Middleware(key, ok)
	cases := []struct {
		name  string
		token string
		want  int
	}{
		{"no token", "", http.StatusUnauthorized},
		{"valid token", good, http.StatusOK},
		{"wrong key", forged, http.StatusUnauthorized},
	}
	for _, c := range cases {
		if got := call(t, h, c.token); got != c.want {
			t.Errorf("%s: got %d, want %d", c.name, got, c.want)
		}
	}
}

func TestRequireRole(t *testing.T) {
	ok := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) { w.WriteHeader(http.StatusOK) })
	clerk, _ := jwtkit.Sign(jwtkit.Claims{"sub": "u1", "role": "clerk"}, key)
	admin, _ := jwtkit.Sign(jwtkit.Claims{"sub": "u2", "role": "admin"}, key)
	h := Middleware(key, RequireRole("admin", ok))
	if got := call(t, h, clerk); got != http.StatusForbidden {
		t.Errorf("clerk: got %d, want 403", got)
	}
	if got := call(t, h, admin); got != http.StatusOK {
		t.Errorf("admin: got %d, want 200", got)
	}
}
