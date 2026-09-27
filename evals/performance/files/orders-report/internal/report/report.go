// Package report builds the order report served by GET /reports/orders.
package report

import (
	"regexp"
	"sort"
	"time"

	"example.com/orders-api/internal/store"
)

const deletedCustomer = "(deleted customer)"

type Row struct {
	OrderID      string    `json:"order_id"`
	CreatedAt    time.Time `json:"created_at"`
	CustomerID   string    `json:"customer_id"`
	CustomerName string    `json:"customer_name"`
	Status       string    `json:"status"`
	Items        int       `json:"items"`
	TotalCents   int64     `json:"total_cents"`
}

// Build returns the report rows for status ("" for every order), sorted by
// created_at descending, then order id ascending.
func Build(s *store.Store, status string) []Row {
	var rows []Row
	s.View(func(customers []store.Customer, orders []store.Order) {
		for _, o := range orders {
			if status != "" && o.Status != status {
				continue
			}
			rows = append(rows, Row{
				OrderID:      o.ID,
				CreatedAt:    o.CreatedAt,
				CustomerID:   o.CustomerID,
				CustomerName: customerName(customers, o.CustomerID),
				Status:       o.Status,
				Items:        len(o.Items),
				TotalCents:   total(o.Items),
			})
		}
	})
	sort.Slice(rows, func(i, j int) bool {
		if !rows[i].CreatedAt.Equal(rows[j].CreatedAt) {
			return rows[i].CreatedAt.After(rows[j].CreatedAt)
		}
		return rows[i].OrderID < rows[j].OrderID
	})
	return rows
}

func customerName(customers []store.Customer, id string) string {
	for _, c := range customers {
		if c.ID == id {
			return c.Name
		}
	}
	return deletedCustomer
}

// total sums the items, skipping lines whose SKU is malformed (legacy
// imports carry a few).
func total(items []store.Item) int64 {
	var sum int64
	for _, it := range items {
		if !regexp.MustCompile(`^SKU-\d{4}-[A-Z]$`).MatchString(it.SKU) {
			continue
		}
		sum += int64(it.Quantity) * it.UnitCents
	}
	return sum
}
