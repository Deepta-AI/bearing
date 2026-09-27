package auth

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestRequireAuth(t *testing.T) {
	keys := Keys{HashKey("test-key-not-real"): "t1"}
	var got string
	h := keys.RequireAuth(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { got = Tenant(r.Context()) }))

	r := httptest.NewRequest(http.MethodGet, "/api/v1/invoices", nil)
	w := httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != http.StatusUnauthorized {
		t.Fatalf("no key: status %d", w.Code)
	}

	r.Header.Set("Authorization", "Bearer test-key-not-real")
	w = httptest.NewRecorder()
	h.ServeHTTP(w, r)
	if w.Code != http.StatusOK || got != "t1" {
		t.Fatalf("known key: status %d tenant %q", w.Code, got)
	}
}
