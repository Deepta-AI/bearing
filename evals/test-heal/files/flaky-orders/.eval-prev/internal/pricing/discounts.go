// Package pricing applies the storefront's order discounts.
package pricing

// Rule is one discount: Percent off when the subtotal reaches MinSubtotal.
type Rule struct {
	Code        string
	MinSubtotal int // rupees
	Percent     int
}

// Rules are the live discounts.
var Rules = []Rule{
	{Code: "WELCOME5", MinSubtotal: 0, Percent: 5},
	{Code: "SAVE10", MinSubtotal: 1000, Percent: 10},
	{Code: "BIG15", MinSubtotal: 2500, Percent: 15},
}

// BestDiscount returns the applicable rule with the largest percentage;
// only one discount applies to an order. ok is false when none applies.
func BestDiscount(subtotal int, eligible map[string]bool) (best Rule, ok bool) {
	for _, r := range Rules {
		if !eligible[r.Code] || subtotal < r.MinSubtotal {
			continue
		}
		if !ok || r.Percent > best.Percent {
			best, ok = r, true
		}
	}
	return best, ok
}

// Total applies the best discount to the subtotal, rounding down.
func Total(subtotal int, eligible map[string]bool) int {
	r, ok := BestDiscount(subtotal, eligible)
	if !ok {
		return subtotal
	}
	return subtotal - subtotal*r.Percent/100
}
