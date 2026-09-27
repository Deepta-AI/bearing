package links

import (
	"testing"
	"time"
)

var t0 = time.Date(2026, 9, 1, 12, 0, 0, 0, time.UTC)

func TestNewExpirerReturnsExpirer(t *testing.T) {
	e := NewExpirer(nil, ExpirerOptions{})
	if e == nil {
		t.Fatal("NewExpirer returned nil")
	}
	if _, ok := e.(*clockExpirer); !ok {
		t.Fatalf("NewExpirer returned %T, want *clockExpirer", e)
	}
}

func TestExpiredCallsOnExpire(t *testing.T) {
	called := 0
	e := NewExpirer(func() time.Time { return t0 }, ExpirerOptions{OnExpire: func(Link) { called++ }})
	e.Expired(Link{ExpiresAt: t0.Add(-time.Minute)})
	if called != 1 {
		t.Fatalf("OnExpire called %d times, want 1", called)
	}
}

func TestRemaining(t *testing.T) {
	e := NewExpirer(func() time.Time { return t0 }, ExpirerOptions{})
	if got := e.Remaining(Link{ExpiresAt: t0.Add(time.Hour)}); got != time.Hour {
		t.Fatalf("Remaining = %v, want 1h", got)
	}
	if got := e.Remaining(Link{ExpiresAt: t0.Add(-time.Hour)}); got != 0 {
		t.Fatalf("Remaining after expiry = %v, want 0", got)
	}
}

func TestStoreExpired(t *testing.T) {
	s, err := Open("")
	if err != nil {
		t.Fatal(err)
	}
	for _, l := range []Link{
		{Code: "keep", URL: "https://example.com/a"},
		{Code: "past", URL: "https://example.com/b", ExpiresAt: t0.Add(-time.Second)},
		{Code: "now", URL: "https://example.com/c", ExpiresAt: t0},
		{Code: "later", URL: "https://example.com/d", ExpiresAt: t0.Add(time.Second)},
	} {
		if err := s.Put(l); err != nil {
			t.Fatal(err)
		}
	}
	got := s.Expired(t0)
	if len(got) != 2 || got[0].Code != "now" || got[1].Code != "past" {
		t.Fatalf("Expired = %+v, want now and past", got)
	}
}
