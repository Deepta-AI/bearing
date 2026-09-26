// Package sms sends order notifications by SMS.
package sms

import "fmt"

// Sender is the SMS provider.
type Sender interface {
	Send(phone, text string) error
}

// OrderPaid texts the customer that their order was paid.
func OrderPaid(s Sender, phone, orderID string) error {
	return s.Send(phone, fmt.Sprintf("Payment received for order %s.", orderID))
}
