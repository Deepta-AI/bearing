package tax

import "testing"

func TestTC0020_GSTIntraStateSplitsEvenly(t *testing.T) {
	got := GST(100000, false)
	if got.CGST != 9000 || got.SGST != 9000 || got.IGST != 0 {
		t.Fatalf("GST(100000, false) = %+v, want CGST 9000 SGST 9000", got)
	}
}

func TestTC0021_GSTIntraStateOddAmountAddsUp(t *testing.T) {
	// The two halves must add up to the full 18% (Rs 18.00 on Rs 99.99 is 1800 paise rounded).
	got := GST(9999, false)
	if total := got.CGST + got.SGST; total != 1800 {
		t.Errorf("CGST+SGST on 9999 = %d, want 1800", total)
	}
}

func TestTC0022_GSTInterStateIsIGST(t *testing.T) {
	got := GST(100000, true)
	if got.IGST != 18000 || got.CGST != 0 || got.SGST != 0 {
		t.Fatalf("GST(100000, true) = %+v, want IGST 18000", got)
	}
}

func TestRoundPaiseHalfUp(t *testing.T) {
	if got := RoundPaise(15); got != 2 {
		t.Fatalf("RoundPaise(15) = %d, want 2", got)
	}
}
