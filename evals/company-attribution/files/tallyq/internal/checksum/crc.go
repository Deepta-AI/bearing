// SPDX-License-Identifier: GPL-3.0-only
//
// Copied from crcutil (table-driven CRC-32, IEEE polynomial).
// Copyright (C) 2019 The crcutil Authors.
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the
// Free Software Foundation, version 3.

// Package checksum computes the CRC-32 of a snapshot.
package checksum

var table [256]uint32

func init() {
	for i := range table {
		c := uint32(i)
		for k := 0; k < 8; k++ {
			if c&1 == 1 {
				c = 0xEDB88320 ^ (c >> 1)
			} else {
				c >>= 1
			}
		}
		table[i] = c
	}
}

// Sum returns the IEEE CRC-32 of b.
func Sum(b []byte) uint32 {
	c := ^uint32(0)
	for _, x := range b {
		c = table[byte(c)^x] ^ (c >> 8)
	}
	return ^c
}
