package store

import "testing"

func TestQuery(t *testing.T) {
	q, ok := Query("get_order")
	if !ok || q == "" {
		t.Fatal("get_order missing")
	}
	if _, ok := Query("nope"); ok {
		t.Fatal("unknown query found")
	}
	if n := len(Names()); n != 4 {
		t.Fatalf("want 4 queries, got %d", n)
	}
}
