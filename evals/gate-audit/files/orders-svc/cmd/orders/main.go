package main

import (
	"fmt"

	"example.com/orders/internal/orders"
	"example.com/orders/internal/store"
)

func main() {
	o := orders.Order{Lines: []orders.Line{{SKU: "tee", UnitPaise: 49900, Qty: 2}}}
	total, _ := orders.Total(o, "")
	fmt.Println("total paise:", total)
	fmt.Println(len(store.Names()), "queries loaded")
}
