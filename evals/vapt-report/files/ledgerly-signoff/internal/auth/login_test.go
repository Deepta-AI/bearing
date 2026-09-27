package auth

import "testing"

func TestSafeNext(t *testing.T) {
	for in, want := range map[string]string{
		"/invoices":            "/invoices",
		"":                     "/",
		"https://evil.example": "/",
		"//evil.example":       "/",
		"/\\evil.example":      "/",
	} {
		if got := SafeNext(in); got != want {
			t.Errorf("SafeNext(%q) = %q, want %q", in, got, want)
		}
	}
}
