package payments

import "testing"

func TestBatches(t *testing.T) {
	for n, want := range map[int]int{0: 0, 1: 1, 500: 1, 501: 2} {
		if got := Batches(n); got != want {
			t.Fatalf("Batches(%d) = %d, want %d", n, got, want)
		}
	}
}
