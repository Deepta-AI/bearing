package ratelimit

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func fixedClock(t time.Time) func() time.Time { return func() time.Time { return t } }

func TestAllowPerKeyWindow(t *testing.T) {
	l := New(3)
	l.now = fixedClock(time.Date(2026, 9, 20, 10, 0, 15, 0, time.UTC))
	for i := 0; i < 3; i++ {
		if ok, _ := l.Allow("k1"); !ok {
			t.Fatalf("request %d rejected, want allowed", i+1)
		}
	}
	if ok, _ := l.Allow("k1"); ok {
		t.Fatal("fourth request allowed, want rejected")
	}
	if ok, _ := l.Allow("k2"); !ok {
		t.Fatal("other key rejected, want its own window")
	}
	l.now = fixedClock(time.Date(2026, 9, 20, 10, 1, 0, 0, time.UTC))
	if ok, _ := l.Allow("k1"); !ok {
		t.Fatal("new window rejected, want allowed")
	}
}

func TestMiddlewareRejectsOverLimit(t *testing.T) {
	l := New(1)
	l.now = fixedClock(time.Date(2026, 9, 20, 10, 0, 45, 0, time.UTC))
	h := l.Middleware(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {}))
	req := httptest.NewRequest(http.MethodGet, "/v1/orders", nil)
	req.Header.Set("X-API-Key", "k1")

	first := httptest.NewRecorder()
	h.ServeHTTP(first, req)
	if first.Code != http.StatusOK {
		t.Fatalf("first request: got %d, want 200", first.Code)
	}
	second := httptest.NewRecorder()
	h.ServeHTTP(second, req)
	if second.Code != http.StatusTooManyRequests {
		t.Fatalf("second request: got %d, want 429", second.Code)
	}
	if second.Header().Get("Retry-After") == "" {
		t.Fatal("429 without Retry-After")
	}
}
