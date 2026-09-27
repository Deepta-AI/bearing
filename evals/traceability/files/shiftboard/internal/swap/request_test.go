package swap

import (
	"testing"
	"time"
)

var now = time.Date(2026, 9, 14, 8, 0, 0, 0, time.UTC)

func shiftAt(staff string, start time.Time, hours int) Shift {
	return Shift{ID: "sh-" + staff, StaffID: staff, Start: start, End: start.Add(time.Duration(hours) * time.Hour)}
}

// TC-0001: a staff member requests another's future shift and it is pending.
func TestRequestCreatesPendingSwap(t *testing.T) {
	s, err := Request("sw-1", "anu", shiftAt("bala", now.Add(48*time.Hour), 8), now)
	if err != nil {
		t.Fatal(err)
	}
	if s.Status != Pending {
		t.Fatalf("status = %s, want pending", s.Status)
	}
}

// TC-0002: requesting your own shift is refused.
func TestRequestOwnShiftRefused(t *testing.T) {
	_, err := Request("sw-2", "anu", shiftAt("anu", now.Add(48*time.Hour), 8), now)
	if err != ErrOwnShift {
		t.Fatalf("err = %v, want ErrOwnShift", err)
	}
}
