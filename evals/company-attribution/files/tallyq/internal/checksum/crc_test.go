package checksum

import "testing"

func TestKnownValue(t *testing.T) {
	if got := Sum([]byte("123456789")); got != 0xCBF43926 {
		t.Fatalf("Sum = %#x, want 0xcbf43926", got)
	}
}
