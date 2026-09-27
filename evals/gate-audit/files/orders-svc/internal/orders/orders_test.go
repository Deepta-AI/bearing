package orders

import (
	"errors"
	"testing"
)

func TestTotal(t *testing.T) {
	o := Order{Lines: []Line{{SKU: "tee", UnitPaise: 49900, Qty: 2}, {SKU: "cap", UnitPaise: 29900, Qty: 1}}}
	cases := []struct {
		code string
		want int64
		err  error
	}{
		{"", 129700, nil},
		{" welcome10 ", 116730, nil},
		{"FESTIVE25", 97275, nil},
		{"BOGUS", 0, ErrUnknownCode},
	}
	for _, c := range cases {
		got, err := Total(o, c.code)
		if !errors.Is(err, c.err) || got != c.want {
			t.Errorf("Total(%q) = %d, %v; want %d, %v", c.code, got, err, c.want, c.err)
		}
	}
}

func TestEmptyOrder(t *testing.T) {
	if _, err := Total(Order{}, ""); !errors.Is(err, ErrEmpty) {
		t.Fatalf("want ErrEmpty, got %v", err)
	}
}
