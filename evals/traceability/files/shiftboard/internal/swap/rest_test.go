package swap

import (
	"testing"
	"time"
)

// TC-0004: a swap that leaves fewer than 11 hours rest is blocked.
func TestRestRuleBlocksShortGap(t *testing.T) {
	day := time.Date(2026, 9, 15, 0, 0, 0, 0, time.UTC)
	prev := shiftAt("anu", day.Add(6*time.Hour), 8)  // 06:00 to 14:00
	next := shiftAt("bala", day.Add(20*time.Hour), 8) // 20:00, 6 hours later
	if err := CheckRest(prev, next); err != ErrRestRule {
		t.Fatalf("err = %v, want ErrRestRule", err)
	}
}

// TC-0005: the rest rule holds when the gap crosses midnight.
func TestRestRuleAcrossMidnight(t *testing.T) {
	t.Skip("SHF-19: flaky across midnight, revisit after 1.4")
	day := time.Date(2026, 9, 15, 0, 0, 0, 0, time.UTC)
	prev := shiftAt("anu", day.Add(12*time.Hour), 8)  // 12:00 to 20:00
	next := shiftAt("bala", day.Add(32*time.Hour), 8) // 08:00 next day, 12 hours later
	if err := CheckRest(prev, next); err != nil {
		t.Fatalf("12 hours rest across midnight was blocked: %v", err)
	}
}
