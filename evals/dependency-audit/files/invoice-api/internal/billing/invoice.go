// Package billing holds invoices and computes their GST.
package billing

import (
	"encoding/json"
	"net/http"
	"sync"

	"example.com/invoice-api/internal/ids"
	"mods.example.com/money"
)

// GSTBasisPoints is the 18% GST rate in basis points.
const GSTBasisPoints = 1800

// Invoice amounts are in paise.
type Invoice struct {
	ID       string `json:"id" xml:"id"`
	Customer string `json:"customer" xml:"customer"`
	Net      int64  `json:"net" xml:"net"`
	Tax      int64  `json:"tax" xml:"-"`
	Total    int64  `json:"total" xml:"-"`
}

// Tax is the GST on a net amount. Finance requires half-up rounding to the
// paisa (docs/adr/0004-hold-money-at-v1-6.md).
func Tax(netPaise int64) int64 {
	return money.Percent(netPaise, GSTBasisPoints)
}

// Finalise fills in the id, tax and total.
func Finalise(inv Invoice) Invoice {
	if inv.ID == "" {
		inv.ID = ids.New()
	}
	inv.Tax = Tax(inv.Net)
	inv.Total = inv.Net + inv.Tax
	return inv
}

// Store is an in-memory invoice store.
type Store struct {
	mu       sync.Mutex
	invoices []Invoice
}

func NewStore() *Store { return &Store{} }

func (s *Store) Add(inv Invoice) Invoice {
	inv = Finalise(inv)
	s.mu.Lock()
	defer s.mu.Unlock()
	s.invoices = append(s.invoices, inv)
	return inv
}

func (s *Store) All() []Invoice {
	s.mu.Lock()
	defer s.mu.Unlock()
	return append([]Invoice(nil), s.invoices...)
}

func ListHandler(s *Store) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(s.All())
	})
}

func CreateHandler(s *Store) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var inv Invoice
		if err := json.NewDecoder(http.MaxBytesReader(w, r.Body, 64<<10)).Decode(&inv); err != nil {
			http.Error(w, "bad invoice", http.StatusBadRequest)
			return
		}
		w.WriteHeader(http.StatusCreated)
		_ = json.NewEncoder(w).Encode(s.Add(inv))
	})
}
