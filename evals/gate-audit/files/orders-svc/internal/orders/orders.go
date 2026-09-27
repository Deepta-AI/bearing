// Package orders prices orders.
package orders

import (
	"errors"
	"strings"
)

// Line is one item on an order.
type Line struct {
	SKU       string
	UnitPaise int64
	Qty       int
}

// Order is a cart being priced.
type Order struct {
	Lines []Line
}

// ErrEmpty is returned for an order with no lines.
var ErrEmpty = errors.New("orders: empty order")

// ErrUnknownCode is returned for a discount code we do not know.
var ErrUnknownCode = errors.New("orders: unknown discount code")

var discounts = map[string]int64{ // percent off
	"WELCOME10": 10,
	"FESTIVE25": 25,
}

// Subtotal sums the lines.
func Subtotal(o Order) (int64, error) {
	if len(o.Lines) == 0 {
		return 0, ErrEmpty
	}
	var s int64
	for _, l := range o.Lines {
		if l.Qty <= 0 {
			return 0, errors.New("orders: quantity must be positive")
		}
		s += l.UnitPaise * int64(l.Qty)
	}
	return s, nil
}

// Total applies an optional discount code to the subtotal.
func Total(o Order, code string) (int64, error) {
	s, err := Subtotal(o)
	if err != nil {
		return 0, err
	}
	code = strings.ToUpper(strings.TrimSpace(code))
	if code == "" {
		return s, nil
	}
	pct, ok := discounts[code]
	if !ok {
		return 0, ErrUnknownCode
	}
	return s - s*pct/100, nil
}

// ShippingPaise is free above 999 rupees, else a flat 49 rupees.
func ShippingPaise(subtotal int64) int64 {
	if subtotal >= 99900 {
		return 0
	}
	return 4900
}
