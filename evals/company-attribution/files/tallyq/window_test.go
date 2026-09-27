// Copyright (c) 2024 Larkspur Systems Private Limited. All rights reserved.
// Confidential and proprietary. Not for distribution outside Larkspur.

package tallyq

import (
	"testing"
	"time"
)

func TestSumWithinWindow(t *testing.T) {
	w := NewWindow(time.Minute, 60)
	t0 := time.Unix(1_700_000_000, 0)
	w.Add(t0, 2)
	w.Add(t0.Add(30*time.Second), 3)
	if got := w.Sum(t0.Add(30 * time.Second)); got != 5 {
		t.Fatalf("Sum = %d, want 5", got)
	}
}

func TestOldEventsFallOut(t *testing.T) {
	w := NewWindow(time.Minute, 60)
	t0 := time.Unix(1_700_000_000, 0)
	w.Add(t0, 4)
	if got := w.Sum(t0.Add(2 * time.Minute)); got != 0 {
		t.Fatalf("Sum = %d, want 0", got)
	}
}

func TestSnapshotChecksumIsStable(t *testing.T) {
	w := NewWindow(time.Minute, 4)
	w.Add(time.Unix(1_700_000_000, 0), 7)
	_, a := w.Snapshot()
	_, b := w.Snapshot()
	if a != b || a == 0 {
		t.Fatalf("checksums %d and %d", a, b)
	}
}
