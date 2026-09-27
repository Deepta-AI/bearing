package main

import (
	"fmt"
	"os"
	"strconv"

	"example.com/payouts-service/internal/payout"
)

func main() {
	if len(os.Args) != 2 {
		fmt.Fprintln(os.Stderr, "usage: payouts <amount_minor>")
		os.Exit(2)
	}
	amount, err := strconv.ParseInt(os.Args[1], 10, 64)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(2)
	}
	fee, err := payout.Fee(amount)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println(fee)
}
