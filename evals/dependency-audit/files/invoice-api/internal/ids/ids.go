// Package ids makes invoice ids.
package ids

import "mods.example.com/uuidx"

// New returns a fresh invoice id.
func New() string { return "inv_" + uuidx.New() }
