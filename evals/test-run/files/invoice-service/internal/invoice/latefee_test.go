package invoice

import "testing"

func TestTC0012_LateFeeCappedAt500Rupees(t *testing.T) {
	// 2% of Rs 20,000 for 3 months is Rs 1,200; the cap is Rs 500.
	got := LateFee(2000000, 75)
	if got != 50000 {
		t.Errorf("LateFee(2000000, 75) = %d paise, want 50000 (the Rs 500 cap)", got)
	}
}

func TestTC0013_NoLateFeeWithinGrace(t *testing.T) {
	if got := LateFee(2000000, 7); got != 0 {
		t.Errorf("LateFee within grace = %d, want 0", got)
	}
}
