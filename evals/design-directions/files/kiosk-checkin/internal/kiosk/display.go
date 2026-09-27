package kiosk

import (
	"strings"
	"unicode/utf8"
)

// DisplayName is what a kiosk screen may show for a patient: the first
// name and the initial of the last name. The screen faces the waiting
// room (docs/design/flows/kiosk-checkin/flows.md).
func DisplayName(first, last string) string {
	first = strings.TrimSpace(first)
	last = strings.TrimSpace(last)
	if last == "" {
		return first
	}
	r, _ := utf8.DecodeRuneInString(last)
	return first + " " + string(r) + "."
}
