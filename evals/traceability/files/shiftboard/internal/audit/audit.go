// Package audit records every state change of a swap.
package audit

import "time"

// Entry is one row of the swap audit trail.
type Entry struct {
	SwapID string
	Actor  string
	Action string
	At     time.Time
}

// Log is an append-only audit trail.
type Log struct{ entries []Entry }

// Record appends an entry.
func (l *Log) Record(e Entry) { l.entries = append(l.entries, e) }

// For returns the entries for one swap in the order they were recorded.
func (l *Log) For(swapID string) []Entry {
	var out []Entry
	for _, e := range l.entries {
		if e.SwapID == swapID {
			out = append(out, e)
		}
	}
	return out
}
