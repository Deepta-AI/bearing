package pricing

import "testing"

// TC-0204: when several discounts apply, the largest one wins.
func TestBestDiscountApplied(t *testing.T) {
	eligible := map[string]bool{"SAVE10": true, "BIG15": true}
	if got, want := Total(3000, eligible), 2550; got != want {
		t.Fatalf("Total(3000) = %d, want %d (BIG15, 15%% off)", got, want)
	}
}

func TestNoDiscountBelowMinimum(t *testing.T) {
	eligible := map[string]bool{"SAVE10": true}
	if got := Total(999, eligible); got != 999 {
		t.Fatalf("Total(999) = %d, want 999", got)
	}
}
