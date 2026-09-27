package catalog

import "testing"

func TestSearchMatchesEveryWord(t *testing.T) {
	c := New(Seed())
	r := c.Search("Red shoes", 1)
	if len(r.Products) != 2 {
		t.Fatalf("got %d products, want 2 (red running shoes, red trail shoes)", len(r.Products))
	}
}

func TestSearchPages(t *testing.T) {
	c := New(Seed())
	if n := len(c.Search("", 1).Products); n != 20 {
		t.Fatalf("page 1 has %d products, want 20", n)
	}
	if n := len(c.Search("", 5).Products); n != 0 {
		t.Fatalf("page 5 has %d products, want 0", n)
	}
}

func TestSearchRepeatIsCached(t *testing.T) {
	c := New(Seed())
	a := c.Search("socks", 1)
	b := c.Search("socks", 1)
	if len(a.Products) != len(b.Products) {
		t.Fatal("cached result differs")
	}
}
