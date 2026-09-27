package analytics

import "testing"

func TestPhoneHashIsStableAndHidesTheNumber(t *testing.T) {
	a, b := PhoneHash("9876543210"), PhoneHash("9876543210")
	if a != b {
		t.Fatal("hash not stable")
	}
	if len(a) != 64 || a == "9876543210" {
		t.Fatalf("unexpected hash %q", a)
	}
}
