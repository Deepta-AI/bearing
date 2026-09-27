// Package ledger keeps account balances as double-entry postings in minor units.
package ledger

import (
	"errors"
	"sync"
)

// ErrUnbalanced is returned when a transfer's postings do not sum to zero.
var ErrUnbalanced = errors.New("ledger: postings do not balance")

// Posting moves Amount minor units into (positive) or out of (negative) an account.
type Posting struct {
	Account string
	Amount  int64
}

// Book holds the postings applied so far.
type Book struct {
	mu       sync.Mutex
	balances map[string]int64
}

// New returns an empty book.
func New() *Book { return &Book{balances: map[string]int64{}} }

// Apply records the postings of one transfer, or none of them.
func (b *Book) Apply(ps ...Posting) error {
	var sum int64
	for _, p := range ps {
		sum += p.Amount
	}
	if sum != 0 || len(ps) < 2 {
		return ErrUnbalanced
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	for _, p := range ps {
		b.balances[p.Account] += p.Amount
	}
	return nil
}

// Balance returns the account's balance in minor units.
func (b *Book) Balance(account string) int64 {
	b.mu.Lock()
	defer b.mu.Unlock()
	return b.balances[account]
}
