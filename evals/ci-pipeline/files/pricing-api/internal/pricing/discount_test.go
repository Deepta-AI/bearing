package pricing

import "testing"

func TestApplyDiscount(t *testing.T) {
	cases := []struct {
		name    string
		price   int64
		percent int64
		want    int64
	}{
		{"no discount", 1000, 0, 1000},
		{"full discount", 1000, 100, 0},
		{"15% of 2000", 2000, 15, 1700},
		{"10% of 995 rounds half up", 995, 10, 896},
		{"5% of 999 rounds down", 999, 5, 949},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := Apply(c.price, c.percent)
			if err != nil {
				t.Fatal(err)
			}
			if got != c.want {
				t.Fatalf("Apply(%d, %d) = %d, want %d", c.price, c.percent, got, c.want)
			}
		})
	}
}

func TestApplyRejectsBadPercent(t *testing.T) {
	for _, p := range []int64{-1, 101} {
		if _, err := Apply(1000, p); err != ErrPercent {
			t.Fatalf("Apply(1000, %d) error = %v, want ErrPercent", p, err)
		}
	}
}

func TestBulk(t *testing.T) {
	for q, want := range map[int64]int64{1: 0, 9: 0, 10: 5, 49: 5, 50: 10, 99: 10, 100: 15, 1000: 15} {
		if got := Bulk(q); got != want {
			t.Errorf("Bulk(%d) = %d, want %d", q, got, want)
		}
	}
}
