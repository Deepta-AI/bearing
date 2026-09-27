package notify

import (
	"testing"
	"time"
)

// TC-0203: placing an order sends exactly one receipt for it.
func TestReceiptSentAfterOrder(t *testing.T) {
	rec := &RecordingSender{}
	n := New(rec)
	n.OrderPlaced("ord-1001")

	time.Sleep(10 * time.Millisecond) // give the background sender time to run

	sent := rec.Sent()
	if len(sent) != 1 || sent[0] != "ord-1001" {
		t.Fatalf("sent %v, want [ord-1001]", sent)
	}
}

func TestOrderPlacedDoesNotBlock(t *testing.T) {
	n := New(&RecordingSender{})
	start := time.Now()
	n.OrderPlaced("ord-1002")
	if d := time.Since(start); d > 5*time.Millisecond {
		t.Fatalf("OrderPlaced took %v; it must return at once", d)
	}
}
