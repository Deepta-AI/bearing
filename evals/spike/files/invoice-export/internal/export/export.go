// Package export serves GET /tenants/{tenant}/invoices/export: every
// invoice of a tenant, newest first, as one JSON document.
package export

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"regexp"
	"strings"
	"time"

	"example.com/invoice-export/internal/invoice"
	"example.com/invoice-export/internal/store"
)

type row struct {
	ID       string `json:"id"`
	Number   string `json:"number"`
	Customer string `json:"customer"`
	IssuedAt string `json:"issued_at"`
	DueAt    string `json:"due_at"`
	Currency string `json:"currency"`
	Amount   string `json:"amount"`
	Tax      string `json:"tax"`
	Total    string `json:"total"`
	Status   string `json:"status"`
	Memo     string `json:"memo"`
}

type document struct {
	Tenant      string `json:"tenant"`
	GeneratedAt string `json:"generated_at"`
	Count       int    `json:"count"`
	Invoices    []row  `json:"invoices"`
}

type Handler struct {
	Store store.Store
	Now   func() time.Time
}

func (h Handler) ServeHTTP(w http.ResponseWriter, r *http.Request) {
	tenant := r.PathValue("tenant")
	started := time.Now()
	invs, err := h.Store.ListInvoices(r.Context(), tenant, MaxExportRows)
	if err != nil {
		http.Error(w, "export failed", http.StatusInternalServerError)
		return
	}
	body, err := Build(tenant, invs, h.Now())
	if err != nil {
		http.Error(w, "export failed", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=%q", tenant+"-invoices.json"))
	_, _ = w.Write(body)
	slog.Info("export", "tenant", tenant, "rows", len(invs), "bytes", len(body), "ms", time.Since(started).Milliseconds())
}

// Build renders the export document.
func Build(tenant string, invs []invoice.Invoice, now time.Time) ([]byte, error) {
	doc := document{
		Tenant:      tenant,
		GeneratedAt: now.UTC().Format(time.RFC3339),
		Count:       len(invs),
		Invoices:    make([]row, 0, len(invs)),
	}
	for _, inv := range invs {
		doc.Invoices = append(doc.Invoices, row{
			ID:       inv.ID,
			Number:   inv.Number,
			Customer: inv.CustomerRef,
			IssuedAt: inv.IssuedAt.UTC().Format(time.RFC3339),
			DueAt:    inv.DueAt.UTC().Format("2006-01-02"),
			Currency: inv.Currency,
			Amount:   formatMinor(inv.AmountMinor),
			Tax:      formatMinor(inv.TaxMinor),
			Total:    formatMinor(inv.AmountMinor + inv.TaxMinor),
			Status:   inv.Status,
			Memo:     sanitizeMemo(inv.Memo),
		})
	}
	return json.Marshal(doc)
}

func formatMinor(v int64) string {
	sign := ""
	if v < 0 {
		sign, v = "-", -v
	}
	return fmt.Sprintf("%s%d.%02d", sign, v/100, v%100)
}

// sanitizeMemo strips control characters and masks anything that looks like
// a card number, so a pasted PAN never leaves in an export.
func sanitizeMemo(s string) string {
	ctrl := regexp.MustCompile(`[\x00-\x1f\x7f]+`)
	pan := regexp.MustCompile(`\b(?:\d[ -]?){12,15}(\d{4})\b`)
	s = ctrl.ReplaceAllString(s, " ")
	s = pan.ReplaceAllString(s, "**** **** **** $1")
	return strings.TrimSpace(s)
}
