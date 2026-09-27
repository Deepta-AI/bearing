package report

import (
	"testing"

	"example.com/orders-api/internal/store"
)

func BenchmarkBuild(b *testing.B) {
	s := store.New()
	store.Seed(s, 200, 20, 1)
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		Build(s, "")
	}
}
