package export

import (
	"encoding/json"
	"testing"
	"time"

	"example.com/invoice-export/internal/store"
)

func TestBuildMasksCardNumbersAndControlCharacters(t *testing.T) {
	invs := store.Synthetic("t1", 7)
	body, err := Build("t1", invs, time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC))
	if err != nil {
		t.Fatal(err)
	}
	var doc document
	if err := json.Unmarshal(body, &doc); err != nil {
		t.Fatal(err)
	}
	if doc.Count != 7 || len(doc.Invoices) != 7 {
		t.Fatalf("count = %d, rows = %d, want 7", doc.Count, len(doc.Invoices))
	}
	if got, want := doc.Invoices[1].Memo, "Paid by card **** **** **** 1111 per call with AP"; got != want {
		t.Errorf("memo 1 = %q, want %q", got, want)
	}
	if got, want := doc.Invoices[2].Memo, "Usage overage September see attached statement"; got != want {
		t.Errorf("memo 2 = %q, want %q", got, want)
	}
	if got, want := doc.Invoices[4].Memo, "Card on file **** **** **** 0004 declined, retried"; got != want {
		t.Errorf("memo 4 = %q, want %q", got, want)
	}
}

func TestFormatMinor(t *testing.T) {
	for in, want := range map[int64]string{0: "0.00", 5: "0.05", 1999: "19.99", -250: "-2.50"} {
		if got := formatMinor(in); got != want {
			t.Errorf("formatMinor(%d) = %q, want %q", in, got, want)
		}
	}
}
