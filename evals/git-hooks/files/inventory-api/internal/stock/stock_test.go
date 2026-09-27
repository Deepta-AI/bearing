package stock

import (
	"encoding/json"
	"os"
	"testing"
)

func TestReserveWithinLevel(t *testing.T) {
	s := NewStore()
	s.Receive("SKU-1", 5)
	if err := s.Reserve("SKU-1", 3); err != nil {
		t.Fatal(err)
	}
	if l, _ := s.Level("SKU-1"); l != 2 {
		t.Fatalf("level = %d, want 2", l)
	}
}

func TestReserveBeyondLevelLeavesStock(t *testing.T) {
	s := NewStore()
	s.Receive("SKU-1", 2)
	if err := s.Reserve("SKU-1", 3); err != ErrInsufficient {
		t.Fatalf("err = %v, want ErrInsufficient", err)
	}
	if l, _ := s.Level("SKU-1"); l != 2 {
		t.Fatalf("level = %d, want 2", l)
	}
}

func TestSampleReceipts(t *testing.T) {
	b, err := os.ReadFile("../../testdata/receipts-sample.json")
	if err != nil {
		t.Fatal(err)
	}
	var rows []struct {
		SKU string `json:"sku"`
		Qty int    `json:"qty"`
	}
	if err := json.Unmarshal(b, &rows); err != nil {
		t.Fatal(err)
	}
	s := NewStore()
	for _, r := range rows {
		s.Receive(r.SKU, r.Qty)
	}
	if l, _ := s.Level("SKU-7"); l != 12 {
		t.Fatalf("SKU-7 level = %d, want 12", l)
	}
}
