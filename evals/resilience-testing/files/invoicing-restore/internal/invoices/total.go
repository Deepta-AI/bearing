package invoices

type Line struct {
	Description string
	Quantity    int64
	UnitCents   int64
}

// Total returns the invoice total in cents with tax at taxBasisPoints
// (1800 = 18 percent), rounded half up.
func Total(lines []Line, taxBasisPoints int64) int64 {
	var net int64
	for _, l := range lines {
		net += l.Quantity * l.UnitCents
	}
	tax := (net*taxBasisPoints + 5000) / 10000
	return net + tax
}
