// Package invoice holds invoices, their totals and late fees.
package invoice

// Status is the lifecycle state of an invoice.
type Status string

const (
	Draft  Status = "draft"
	Issued Status = "issued"
	Paid   Status = "paid"
)

// Line is one billed item, amounts in paise.
type Line struct {
	Description string
	AmountPaise int64
}

// Invoice is a bill for one customer.
type Invoice struct {
	ID      string
	Status  Status
	Lines   []Line
	Credits []int64
}

// New returns a draft invoice.
func New(id string) *Invoice {
	return &Invoice{ID: id, Status: Draft}
}

// Total is the sum of the lines less any credit notes, in paise.
func (i *Invoice) Total() int64 {
	var t int64
	for _, l := range i.Lines {
		t += l.AmountPaise
	}
	for _, c := range i.Credits {
		t -= c
	}
	return t
}
