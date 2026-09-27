// Package pricing applies the storefront's order discounts.
package pricing

// Rule is one discount: Percent off when the subtotal reaches MinSubtotal.
type Rule struct {
	MinSubtotal int // rupees
	Percent     int
}

// Rules are the live discounts, keyed by code so the admin screen can look
// one up without a scan.
var Rules = map[string]Rule{
	"BIG15":    {MinSubtotal: 2500, Percent: 15},
	"SAVE10":   {MinSubtotal: 1000, Percent: 10},
	"WELCOME5": {MinSubtotal: 0, Percent: 5},
}

// Lookup returns the rule for a code.
func Lookup(code string) (Rule, bool) {
	r, ok := Rules[code]
	return r, ok
}

// BestDiscount returns the applicable rule for the order; only one
// discount applies to an order. ok is false when none applies.
func BestDiscount(subtotal int, eligible map[string]bool) (best Rule, ok bool) {
	for code, r := range Rules {
		if !eligible[code] || subtotal < r.MinSubtotal {
			continue
		}
		return r, true
	}
	return Rule{}, false
}

// Total applies the best discount to the subtotal, rounding down.
func Total(subtotal int, eligible map[string]bool) int {
	r, ok := BestDiscount(subtotal, eligible)
	if !ok {
		return subtotal
	}
	return subtotal - subtotal*r.Percent/100
}
