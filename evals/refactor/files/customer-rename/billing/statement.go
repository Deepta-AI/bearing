package billing

import (
	"encoding/json"
	"io"
)

// Statement is one month's bill for a client. The month-end job writes one
// per active client for the finance importer (docs/statements.md).
type Statement struct {
	Period      string
	Client      Client
	AmountPaise int64
}

// NewStatement returns the statement for one client and period (YYYY-MM).
func NewStatement(c Client, period string) Statement {
	return Statement{Period: period, Client: c, AmountPaise: c.MonthlyPaise}
}

// WriteStatements writes the statements of every active client as JSON lines.
func (s *Store) WriteStatements(w io.Writer, period string) error {
	enc := json.NewEncoder(w)
	for _, c := range s.ActiveClients() {
		if err := enc.Encode(NewStatement(c, period)); err != nil {
			return err
		}
	}
	return nil
}
