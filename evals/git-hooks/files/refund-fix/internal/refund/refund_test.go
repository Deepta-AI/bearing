package refund

import "testing"

func TestPartialWholeLine(t *testing.T) {
	got, err := Partial(30000, 3, 3)
	if err != nil || got != 30000 {
		t.Fatalf("Partial = %d, %v; want 30000", got, err)
	}
}

func TestPartialOverRefund(t *testing.T) {
	if _, err := Partial(30000, 3, 4); err != ErrOverRefund {
		t.Fatalf("err = %v, want ErrOverRefund", err)
	}
}
