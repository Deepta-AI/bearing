package payment

import "testing"

// US-02-001: capture up to the authorised amount.
func TestCaptureWithinAuthorisation(t *testing.T) {
	p, err := Capture(Payment{ID: "p1", Authorised: 50000}, 50000)
	if err != nil || p.Captured != 50000 {
		t.Fatalf("capture: %v %d", err, p.Captured)
	}
}

// US-02-002: a capture over the authorised amount is refused.
func TestCaptureOverAuthorisationRefused(t *testing.T) {
	if _, err := Capture(Payment{ID: "p1", Authorised: 50000}, 50001); err != ErrOverCapture {
		t.Fatalf("err = %v", err)
	}
}
