// Package collect gathers the host metrics the agent reports.
package collect

import (
	"runtime"

	"example.net/sys/diskstat"
)

// Host returns disk counters plus the CPU count.
func Host(diskstatsPath string) (map[string]float64, error) {
	m, err := diskstat.Read(diskstatsPath)
	if err != nil {
		return nil, err
	}
	m["cpu.count"] = float64(runtime.NumCPU())
	return m, nil
}
