// Copyright (c) 2024 Larkspur Systems Private Limited. All rights reserved.
// Confidential and proprietary. Not for distribution outside Larkspur.

// Command tallyq reads RFC 3339 timestamps on stdin and prints the count
// of events in the last minute after each line.
package main

import (
	"bufio"
	"fmt"
	"os"
	"time"

	"git.larkspur.dev/larkspur/tallyq"
)

func main() {
	w := tallyq.NewWindow(time.Minute, 60)
	sc := bufio.NewScanner(os.Stdin)
	for sc.Scan() {
		ts, err := time.Parse(time.RFC3339, sc.Text())
		if err != nil {
			fmt.Fprintln(os.Stderr, "skip:", err)
			continue
		}
		w.Add(ts, 1)
		fmt.Println(w.Sum(ts))
	}
}
