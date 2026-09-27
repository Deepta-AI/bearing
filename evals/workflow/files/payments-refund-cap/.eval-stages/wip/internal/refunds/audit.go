package refunds

// recordRejected writes one refund_audit row for a refused refund attempt.
//
// TODO(PAY-214): write the row once the store has a refund_audit table.
func recordRejected(paymentID string, amount int64, reason string) error {
	_ = paymentID
	_ = amount
	_ = reason
	return nil
}
