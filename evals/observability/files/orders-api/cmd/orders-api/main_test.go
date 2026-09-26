package main

import "testing"

func TestEnvDefault(t *testing.T) {
	if got := env("ORDERS_API_UNSET_FOR_TEST", "x"); got != "x" {
		t.Fatalf("env = %q", got)
	}
}
