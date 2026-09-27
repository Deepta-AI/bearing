package webhook

import "testing"

func TestVerify(t *testing.T) {
	secret := []byte("s3cret")
	body := []byte(`{"id":"evt_1"}`)
	sig := Sign(secret, "1700000000", body)
	if !Verify(secret, "1700000000", body, sig) {
		t.Fatal("a correct signature was rejected")
	}
	if Verify(secret, "1700000001", body, sig) {
		t.Fatal("a signature for another timestamp was accepted")
	}
	if Verify([]byte("other"), "1700000000", body, sig) {
		t.Fatal("a signature made with another secret was accepted")
	}
}
