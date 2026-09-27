// Package assertx has small test assertions.
package assertx

import "testing"

// Equal fails the test when got differs from want.
func Equal[T comparable](t testing.TB, got, want T) {
	t.Helper()
	if got != want {
		t.Fatalf("got %v, want %v", got, want)
	}
}
