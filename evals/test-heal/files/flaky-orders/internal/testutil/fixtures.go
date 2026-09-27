// Package testutil holds the shared test fixtures.
package testutil

import (
	"fmt"
	"math/rand/v2"

	"example.com/orders/internal/store"
)

// Store is the in-memory store the customer tests use.
var Store = store.New()

// Known customers used across the tests.
const (
	AshaEmail = "asha@example.com"
	RaviEmail = "ravi@example.com"
)

// RandomEmail returns a throwaway address for a test customer.
func RandomEmail() string {
	return fmt.Sprintf("user%02d@example.com", rand.IntN(100))
}
