// Package ledger records money movements in paise.
package ledger

// Entry is one movement; Amount is in paise, negative for money out.
type Entry struct {
    Ref    string
    Amount int64
}

// Sum adds the amounts of entries.
func Sum(entries []Entry) int64 {
    var total int64
    for _, e := range entries {
        total += e.Amount
    }
    return total
}
