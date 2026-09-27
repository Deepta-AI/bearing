package store

import (
	"fmt"
	"math/rand"
	"time"
)

var statuses = []string{"paid", "paid", "paid", "pending", "refunded"}

// legacySKUs are malformed lines copied from the nightly snapshot; the
// legacy imports wrote them and they must never be billed.
var legacySKUs = []string{
	"SKU-12345-A",
	"SKU-042-B",
	"sku-0042-a",
	"SKU-0042-a",
	"SKU-0042-AB",
	"SKU-0042-\u00c9",
	"SKU-00\u0664\u0662-A",
	"SKU-\uff10\uff10\uff14\uff12-C",
	"SKU-0042-A\n",
	" SKU-0042-A",
	"SKU_0042_A",
	"",
}

// Seed fills s with a deterministic tenant of the given size. About 2% of
// customers are deleted after their orders are written, as in production.
// Many orders share a created_at second, as the nightly import does.
// About one line in 300 carries a malformed legacy SKU, as in production.
func Seed(s *Store, orders, customers int, seed int64) {
	r := rand.New(rand.NewSource(seed))
	for i := 0; i < customers; i++ {
		_ = s.AddCustomer(Customer{ID: fmt.Sprintf("cus_%06d", i), Name: fmt.Sprintf("Customer %d", i)})
	}
	base := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	for i := 0; i < orders; i++ {
		n := 1 + r.Intn(5)
		items := make([]Item, n)
		for j := range items {
			sku := fmt.Sprintf("SKU-%04d-%s", r.Intn(5000), []string{"A", "B", "C"}[r.Intn(3)])
			if r.Intn(300) == 0 {
				sku = legacySKUs[r.Intn(len(legacySKUs))]
			}
			items[j] = Item{
				SKU:       sku,
				Quantity:  1 + r.Intn(4),
				UnitCents: int64(100 + r.Intn(20000)),
			}
		}
		s.AddOrder(Order{
			ID:         fmt.Sprintf("ord_%07d", i),
			CustomerID: fmt.Sprintf("cus_%06d", r.Intn(customers)),
			Status:     statuses[r.Intn(len(statuses))],
			CreatedAt:  base.Add(time.Duration(r.Intn(orders/4+1)) * time.Minute),
			Items:      items,
		})
	}
	for i := 0; i < customers/50; i++ {
		s.DeleteCustomer(fmt.Sprintf("cus_%06d", r.Intn(customers)))
	}
}
