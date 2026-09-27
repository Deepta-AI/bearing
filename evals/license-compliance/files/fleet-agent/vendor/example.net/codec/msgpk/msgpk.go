// Package msgpk encodes small maps in a compact binary form.
package msgpk

import (
	"encoding/binary"
	"sort"
)

// EncodeMap writes keys in sorted order: uint16 length, key, float64 bits.
func EncodeMap(m map[string]float64) []byte {
	keys := make([]string, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	out := make([]byte, 0, 16*len(m))
	for _, k := range keys {
		out = binary.BigEndian.AppendUint16(out, uint16(len(k)))
		out = append(out, k...)
		out = binary.BigEndian.AppendUint64(out, uint64FromFloat(m[k]))
	}
	return out
}
