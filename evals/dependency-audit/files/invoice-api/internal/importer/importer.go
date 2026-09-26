// Package importer takes the nightly XML export from the ERP and adds its
// invoices to the store.
package importer

import (
	"encoding/json"
	"net/http"

	"example.com/invoice-api/internal/billing"
	"mods.example.com/xmlsafe"
)

// Batch is the ERP export document.
type Batch struct {
	Invoices []billing.Invoice `xml:"invoice"`
}

// Handler decodes an export and stores every invoice in it.
func Handler(s *billing.Store) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		var b Batch
		if err := xmlsafe.Decode(r.Body, &b); err != nil {
			http.Error(w, "bad export", http.StatusBadRequest)
			return
		}
		added := 0
		for _, inv := range b.Invoices {
			s.Add(inv)
			added++
		}
		_ = json.NewEncoder(w).Encode(map[string]int{"added": added})
	})
}
