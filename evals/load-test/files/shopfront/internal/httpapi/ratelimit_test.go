package httpapi

import (
	"testing"
	"time"
)

func TestLimiterPerKey(t *testing.T) {
	now := time.Unix(0, 0)
	l := NewLimiter(20)
	l.now = func() time.Time { return now }
	for i := 0; i < 20; i++ {
		if !l.Allow("a") {
			t.Fatalf("request %d refused inside the burst", i)
		}
	}
	if l.Allow("a") {
		t.Fatal("21st request in the same instant allowed")
	}
	if !l.Allow("b") {
		t.Fatal("a second key shares the first key's bucket")
	}
	now = now.Add(time.Second)
	if !l.Allow("a") {
		t.Fatal("bucket did not refill after a second")
	}
}
