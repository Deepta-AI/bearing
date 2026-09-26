package orders

import (
	"testing"

	"example.com/shopcore/internal/outbox"
)

func TestShipWritesOutbox(t *testing.T) {
	ob := outbox.NewMemory()
	s := NewService(ob, Order{ID: "ord_1", PartnerID: "prt_acme", Status: "paid"})
	if err := s.Ship("ord_1", "Delhivery", "DLV123"); err != nil {
		t.Fatal(err)
	}
	evs, _ := ob.Pending(10)
	if len(evs) != 1 || evs[0].Type != "order.shipped" {
		t.Fatalf("outbox: %+v", evs)
	}
}
