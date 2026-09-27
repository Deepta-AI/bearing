package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHealthEndpoints(t *testing.T) {
	for _, path := range []string{"/healthz", "/readyz"} {
		rec := httptest.NewRecorder()
		routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
		if rec.Code != http.StatusOK {
			t.Fatalf("%s: got %d, want 200", path, rec.Code)
		}
	}
}

func TestDefaultPort(t *testing.T) {
	t.Setenv("PORT", "")
	if got := envOr("PORT", "8101"); got != "8101" {
		t.Fatalf("default port %s, want 8101", got)
	}
}
