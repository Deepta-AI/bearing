package report

import (
	"testing"
	"time"

	"example.com/orders-api/internal/store"
)

func at(min int) time.Time { return time.Date(2026, 8, 1, 10, min, 0, 0, time.UTC) }

func fixture() *store.Store {
	s := store.New()
	_ = s.AddCustomer(store.Customer{ID: "cus_1", Name: "Asha"})
	_ = s.AddCustomer(store.Customer{ID: "cus_2", Name: "Ben"})
	s.AddOrder(store.Order{ID: "ord_1", CustomerID: "cus_1", Status: "paid", CreatedAt: at(1),
		Items: []store.Item{{SKU: "SKU-0001-A", Quantity: 2, UnitCents: 500}}})
	s.AddOrder(store.Order{ID: "ord_2", CustomerID: "cus_2", Status: "pending", CreatedAt: at(3),
		Items: []store.Item{{SKU: "SKU-0002-B", Quantity: 1, UnitCents: 1200}}})
	s.AddOrder(store.Order{ID: "ord_3", CustomerID: "cus_1", Status: "paid", CreatedAt: at(2),
		Items: []store.Item{{SKU: "SKU-0003-C", Quantity: 3, UnitCents: 100}, {SKU: "SKU-0004-A", Quantity: 1, UnitCents: 50}}})
	return s
}

func TestBuildSortsNewestFirst(t *testing.T) {
	rows := Build(fixture(), "")
	want := []string{"ord_2", "ord_3", "ord_1"}
	if len(rows) != len(want) {
		t.Fatalf("got %d rows, want %d", len(rows), len(want))
	}
	for i, id := range want {
		if rows[i].OrderID != id {
			t.Errorf("row %d = %s, want %s", i, rows[i].OrderID, id)
		}
	}
}

func TestBuildFiltersByStatus(t *testing.T) {
	rows := Build(fixture(), "paid")
	if len(rows) != 2 {
		t.Fatalf("got %d paid rows, want 2", len(rows))
	}
	for _, r := range rows {
		if r.Status != "paid" {
			t.Errorf("row %s has status %s", r.OrderID, r.Status)
		}
	}
}

func TestBuildTotalsAndNames(t *testing.T) {
	rows := Build(fixture(), "paid")
	if rows[0].OrderID != "ord_3" || rows[0].TotalCents != 350 || rows[0].CustomerName != "Asha" || rows[0].Items != 2 {
		t.Errorf("unexpected first row %+v", rows[0])
	}
}
