// Copyright (c) 2021 The ringbuf Authors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// Package ringbuf is a fixed-size ring of int64 values.
package ringbuf

// Ring holds the last n values pushed.
type Ring struct {
	vals []int64
	next int
}

// New returns a ring of n zeroes.
func New(n int) *Ring { return &Ring{vals: make([]int64, n)} }

// Push appends v, dropping the oldest value.
func (r *Ring) Push(v int64) {
	r.vals[r.next] = v
	r.next = (r.next + 1) % len(r.vals)
}

// AddLast adds v to the most recently pushed value.
func (r *Ring) AddLast(v int64) {
	i := (r.next - 1 + len(r.vals)) % len(r.vals)
	r.vals[i] += v
}

// Values returns the values oldest first.
func (r *Ring) Values() []int64 {
	out := make([]int64, 0, len(r.vals))
	for i := 0; i < len(r.vals); i++ {
		out = append(out, r.vals[(r.next+i)%len(r.vals)])
	}
	return out
}
