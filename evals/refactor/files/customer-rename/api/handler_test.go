package api

import (
	"bytes"
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"example.com/billingsvc/billing"
)

func testHandler() *Handler {
	return &Handler{
		Store: billing.NewStore([]billing.Client{
			{ID: "c_102", Name: "Meera Textiles", Plan: "pro", Active: true, MonthlyPaise: 249900},
		}),
		Log: slog.New(slog.NewTextHandler(io.Discard, nil)),
	}
}

func get(t *testing.T, path string) *httptest.ResponseRecorder {
	t.Helper()
	rec := httptest.NewRecorder()
	testHandler().Routes().ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec
}

func golden(t *testing.T, name string, got []byte) {
	t.Helper()
	want, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("%s mismatch\ngot:  %s\nwant: %s", name, got, want)
	}
}

func TestGetClientGolden(t *testing.T) {
	rec := get(t, "/clients/c_102")
	if rec.Code != http.StatusOK {
		t.Fatalf("status %d", rec.Code)
	}
	golden(t, "get_client.golden.json", rec.Body.Bytes())
}

func TestGetClientNotFoundGolden(t *testing.T) {
	rec := get(t, "/clients/c_999")
	if rec.Code != http.StatusNotFound {
		t.Fatalf("status %d", rec.Code)
	}
	golden(t, "get_client_404.golden.json", rec.Body.Bytes())
}

func TestClientIPPrefersForwarded(t *testing.T) {
	r := httptest.NewRequest(http.MethodGet, "/", nil)
	r.Header.Set("X-Forwarded-For", "203.0.113.9")
	if got := clientIP(r); got != "203.0.113.9" {
		t.Fatalf("got %q", got)
	}
}
