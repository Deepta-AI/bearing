package api

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestV1AddressesDeprecationHeaders(t *testing.T) {
	rec := httptest.NewRecorder()
	Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/v1/customers/cus_42/addresses", nil))
	if rec.Header().Get("Sunset") == "" || rec.Header().Get("Deprecation") == "" {
		t.Fatalf("missing deprecation headers: %v", rec.Header())
	}
}

func TestV2Addresses(t *testing.T) {
	rec := httptest.NewRecorder()
	Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/v2/customers/cus_42/addresses", nil))
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
}
