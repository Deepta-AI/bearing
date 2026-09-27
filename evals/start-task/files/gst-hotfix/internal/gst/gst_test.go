package gst

import "testing"

func TestTax(t *testing.T) {
	cases := []struct {
		amount, bps, want int64
	}{
		{10000, 1800, 1800},
		{250000, 500, 12500},
		{0, 1800, 0},
	}
	for _, c := range cases {
		if got := Tax(c.amount, c.bps); got != c.want {
			t.Errorf("Tax(%d, %d) = %d, want %d", c.amount, c.bps, got, c.want)
		}
	}
}

func TestSplitOddPaisaGoesToCGST(t *testing.T) {
	c, s := Split(1801)
	if c != 901 || s != 900 {
		t.Fatalf("Split(1801) = %d, %d", c, s)
	}
}
