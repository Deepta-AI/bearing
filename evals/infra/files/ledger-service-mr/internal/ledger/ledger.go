// Package ledger holds the posting rules shared by the API and the worker.
package ledger

import "errors"

// Entry is one side of a posting, in paise.
type Entry struct {
	Account string
	Amount  int64
}

// ErrUnbalanced is returned when a posting's entries do not sum to zero.
var ErrUnbalanced = errors.New("ledger: posting does not balance")

// Validate checks that a posting has at least two entries and balances.
func Validate(entries []Entry) error {
	if len(entries) < 2 {
		return errors.New("ledger: a posting needs two entries")
	}
	var sum int64
	for _, e := range entries {
		sum += e.Amount
	}
	if sum != 0 {
		return ErrUnbalanced
	}
	return nil
}
