// Copyright (c) 2024 Larkspur Systems Private Limited. All rights reserved.
// Confidential and proprietary. Not for distribution outside Larkspur.

// Package tallyq counts events in a sliding time window.
package tallyq

import (
	"encoding/binary"
	"time"

	"git.larkspur.dev/larkspur/tallyq/internal/checksum"
	"git.larkspur.dev/larkspur/tallyq/third_party/ringbuf"
)

// Window keeps one bucket per slot of a fixed width.
type Window struct {
	width time.Duration
	slot  time.Duration
	buf   *ringbuf.Ring
	head  int64
}

// NewWindow returns a window of the given width split into n slots.
func NewWindow(width time.Duration, n int) *Window {
	return &Window{width: width, slot: width / time.Duration(n), buf: ringbuf.New(n)}
}

func (w *Window) advance(now time.Time) {
	idx := now.UnixNano() / int64(w.slot)
	if w.head == 0 {
		w.head = idx
		return
	}
	for w.head < idx {
		w.head++
		w.buf.Push(0)
	}
}

// Add records n events at now.
func (w *Window) Add(now time.Time, n int64) {
	w.advance(now)
	w.buf.AddLast(n)
}

// Sum returns the events recorded within the window ending at now.
func (w *Window) Sum(now time.Time) int64 {
	w.advance(now)
	var s int64
	for _, v := range w.buf.Values() {
		s += v
	}
	return s
}

// Snapshot returns the bucket values and their checksum.
func (w *Window) Snapshot() ([]int64, uint32) {
	vals := w.buf.Values()
	b := make([]byte, 8*len(vals))
	for i, v := range vals {
		binary.LittleEndian.PutUint64(b[8*i:], uint64(v))
	}
	return vals, checksum.Sum(b)
}
