// Package invoice holds the invoice record as the billing store keeps it.
package invoice

import "time"

// Invoice is one issued invoice. Amounts are in minor units (cents).
type Invoice struct {
	ID          string
	TenantID    string
	Number      string
	CustomerRef string
	IssuedAt    time.Time
	DueAt       time.Time
	Currency    string
	AmountMinor int64
	TaxMinor    int64
	Status      string
	Memo        string
}
