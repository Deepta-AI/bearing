// Command fleet-agent collects host metrics and ships them to the fleet
// collector every interval.
package main

import (
	"flag"
	"log"
	"os"
	"time"

	"example.net/cli/flagx"

	"example.org/fleet-agent/internal/collect"
	"example.org/fleet-agent/internal/ship"
)

func main() {
	fs := flag.NewFlagSet("fleet-agent", flag.ExitOnError)
	endpoint := flagx.String(fs, "endpoint", "FLEET_ENDPOINT", "http://127.0.0.1:4318/v1/metrics", "collector URL")
	diskstats := flagx.String(fs, "diskstats", "FLEET_DISKSTATS", "/proc/diskstats", "diskstats file")
	_ = fs.Parse(os.Args[1:])

	s := ship.New(*endpoint)
	for {
		m, err := collect.Host(*diskstats)
		if err != nil {
			log.Printf("collect: %v", err)
		} else if err := s.Send(m); err != nil {
			log.Printf("ship: %v", err)
		}
		time.Sleep(30 * time.Second)
	}
}
