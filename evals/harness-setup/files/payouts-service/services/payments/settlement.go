// Package payments settles payout batches with the bank.
package payments

// BatchSize is how many payouts go into one settlement file.
const BatchSize = 500

// Batches splits n payouts into settlement files of at most BatchSize.
func Batches(n int) int {
	if n <= 0 {
		return 0
	}
	return (n + BatchSize - 1) / BatchSize
}
