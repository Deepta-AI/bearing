package auth

import "testing"

func TestSignParseRoundTrip(t *testing.T) {
	s := Signer{Key: []byte("test-key")}
	got, err := s.Parse(s.Sign(Session{UserID: "u1", TenantID: "t1"}))
	if err != nil || got.UserID != "u1" || got.TenantID != "t1" {
		t.Fatalf("round trip: %+v %v", got, err)
	}
}

func TestParseRejectsTampered(t *testing.T) {
	s := Signer{Key: []byte("test-key")}
	v := s.Sign(Session{UserID: "u1", TenantID: "t1"})
	if _, err := s.Parse("u1.t2" + v[len("u1.t1"):]); err == nil {
		t.Fatal("tampered tenant accepted")
	}
}
