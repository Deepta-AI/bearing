// Copyright (C) 2022 Diskstat Developers
//
// This library is free software: you can redistribute it and/or modify it
// under the terms of the GNU Lesser General Public License version 3 as
// published by the Free Software Foundation. See COPYING.LESSER.

// Package diskstat reads per-device I/O counters.
package diskstat

import (
	"bufio"
	"os"
	"strconv"
	"strings"
)

// Read returns sectors read per device from a /proc/diskstats style file.
func Read(path string) (map[string]float64, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	out := map[string]float64{}
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		fields := strings.Fields(sc.Text())
		if len(fields) < 6 {
			continue
		}
		n, err := strconv.ParseFloat(fields[5], 64)
		if err != nil {
			continue
		}
		out[fields[2]+".sectors_read"] = n
	}
	return out, sc.Err()
}
