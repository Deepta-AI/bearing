package invoices

import "testing"

func TestTotal(t *testing.T) {
	got := Total([]Line{{Quantity: 10, UnitCents: 1500}}, 1800)
	if got != 17700 {
		t.Fatalf("got %d, want 17700", got)
	}
}

func TestTotalRoundsHalfUp(t *testing.T) {
	got := Total([]Line{{Quantity: 1, UnitCents: 25}}, 1800)
	if got != 30 {
		t.Fatalf("got %d, want 30", got)
	}
}
