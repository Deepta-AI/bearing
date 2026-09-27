package share

import (
	"testing"
	"time"
)

func TestResolveReturnsFile(t *testing.T) {
	l := NewLinks()
	tok := l.Create("f1", "t1")
	if id, err := l.Resolve(tok); err != nil || id != "f1" {
		t.Fatalf("Resolve = %q, %v", id, err)
	}
}

func TestResolveUnknownToken(t *testing.T) {
	if _, err := NewLinks().Resolve("nope"); err != ErrNotFound {
		t.Fatalf("err = %v, want ErrNotFound", err)
	}
}

func TestResolveExpired(t *testing.T) {
	now := time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)
	l := NewLinks()
	l.Now = func() time.Time { return now }
	tok := l.Create("f1", "t1")
	now = now.Add(TTL + time.Minute)
	if _, err := l.Resolve(tok); err != ErrNotFound {
		t.Fatalf("expired link resolved: %v", err)
	}
}
