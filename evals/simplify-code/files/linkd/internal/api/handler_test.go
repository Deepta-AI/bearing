package api

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"example.com/linkd/internal/links"
)

var t0 = time.Date(2026, 9, 1, 12, 0, 0, 0, time.UTC)

func newServer(t *testing.T, now *time.Time) http.Handler {
	t.Helper()
	s, err := links.Open("")
	if err != nil {
		t.Fatal(err)
	}
	return New(s, func() time.Time { return *now }).Routes()
}

func do(h http.Handler, method, path, body string) *httptest.ResponseRecorder {
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(method, path, strings.NewReader(body)))
	return rec
}

func create(t *testing.T, h http.Handler, body string) map[string]any {
	t.Helper()
	rec := do(h, "POST", "/links", body)
	if rec.Code != http.StatusCreated {
		t.Fatalf("create: status %d, body %q", rec.Code, rec.Body.String())
	}
	var out map[string]any
	if err := json.Unmarshal(rec.Body.Bytes(), &out); err != nil {
		t.Fatal(err)
	}
	return out
}

func TestCreateThenRedirect(t *testing.T) {
	now := t0
	h := newServer(t, &now)
	code := create(t, h, `{"url":"https://example.com/spring"}`)["code"].(string)
	rec := do(h, "GET", "/"+code, "")
	if rec.Code != http.StatusFound || rec.Header().Get("Location") != "https://example.com/spring" {
		t.Fatalf("get: status %d, location %q", rec.Code, rec.Header().Get("Location"))
	}
}

func TestCreateRejectsBadURL(t *testing.T) {
	now := t0
	h := newServer(t, &now)
	for _, body := range []string{`{"url":"example.com"}`, `{"url":"ftp://example.com/x"}`, `not json`} {
		if rec := do(h, "POST", "/links", body); rec.Code != http.StatusBadRequest {
			t.Errorf("%s: status %d, want 400", body, rec.Code)
		}
	}
}

func TestUnknownCode(t *testing.T) {
	now := t0
	h := newServer(t, &now)
	if rec := do(h, "GET", "/nope123", ""); rec.Code != http.StatusNotFound {
		t.Fatalf("status %d, want 404", rec.Code)
	}
}

func TestLinkExpires(t *testing.T) {
	now := t0
	h := newServer(t, &now)
	out := create(t, h, `{"url":"https://example.com/sale","ttl_seconds":3600}`)
	code := out["code"].(string)
	if out["expires_at"] != "2026-09-01T13:00:00Z" {
		t.Fatalf("expires_at = %v", out["expires_at"])
	}
	now = t0.Add(time.Hour - time.Second)
	if rec := do(h, "GET", "/"+code, ""); rec.Code != http.StatusFound {
		t.Fatalf("before expiry: status %d, want 302", rec.Code)
	}
	now = t0.Add(time.Hour)
	if rec := do(h, "GET", "/"+code, ""); rec.Code != http.StatusGone {
		t.Fatalf("at expiry: status %d, want 410", rec.Code)
	}
}

func TestTTLCappedAtThirtyDays(t *testing.T) {
	now := t0
	h := newServer(t, &now)
	out := create(t, h, `{"url":"https://example.com/long","ttl_seconds":7776000}`)
	if out["expires_at"] != "2026-10-01T12:00:00Z" {
		t.Fatalf("expires_at = %v, want 30 days on", out["expires_at"])
	}
}

func TestNoTTLNeverExpires(t *testing.T) {
	now := t0
	h := newServer(t, &now)
	out := create(t, h, `{"url":"https://example.com/forever"}`)
	if _, ok := out["expires_at"]; ok {
		t.Fatalf("expires_at present for a link without ttl: %v", out)
	}
	now = t0.Add(365 * 24 * time.Hour)
	if rec := do(h, "GET", "/"+out["code"].(string), ""); rec.Code != http.StatusFound {
		t.Fatalf("status %d, want 302", rec.Code)
	}
}

// The spring campaign's printed QR codes end in a slash (docs/api.md).
func TestTrailingSlash(t *testing.T) {
	now := t0
	h := newServer(t, &now)
	code := create(t, h, `{"url":"https://example.com/qr"}`)["code"].(string)
	if rec := do(h, "GET", "/"+code+"/", ""); rec.Code != http.StatusFound {
		t.Fatalf("status %d, want 302", rec.Code)
	}
}
