package share

import "testing"

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
