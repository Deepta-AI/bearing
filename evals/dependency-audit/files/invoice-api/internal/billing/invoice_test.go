package billing

import "testing"

func TestTaxRoundsHalfUp(t *testing.T) {
	cases := []struct{ net, tax int64 }{
		{10000, 1800},
		{1025, 185}, // 184.5 paise rounds up, as finance requires
		{1075, 194}, // 193.5 paise rounds up
		{3, 1},
		{0, 0},
	}
	for _, c := range cases {
		if got := Tax(c.net); got != c.tax {
			t.Errorf("Tax(%d) = %d, want %d", c.net, got, c.tax)
		}
	}
}

func TestFinalise(t *testing.T) {
	inv := Finalise(Invoice{Customer: "c1", Net: 1025})
	if inv.ID == "" || inv.Total != 1210 {
		t.Fatalf("got %+v", inv)
	}
}
