package main

import (
	"fmt"

	"example.com/invoicing/internal/invoices"
)

func main() {
	lines := []invoices.Line{{Description: "Seats", Quantity: 10, UnitCents: 1500}}
	fmt.Println(invoices.Total(lines, 1800))
}
