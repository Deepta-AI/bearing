// Copyright (c) 2016, The Msgpk Authors. All rights reserved.
// Use of this source code is governed by the BSD-style license in LICENSE.
//
// uint64FromFloat and its canonical NaN handling are adapted from fpbits,
// Copyright (c) 2012 Ilse Marchetti, used under the following terms:
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to permit
// persons to whom the Software is furnished to do so, subject to the
// following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN
// NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
// DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE
// USE OR OTHER DEALINGS IN THE SOFTWARE.

package msgpk

import "math"

// canonicalNaN is the single NaN bit pattern written on the wire, so equal
// maps always encode to equal bytes.
const canonicalNaN = 0x7ff8000000000001

func uint64FromFloat(f float64) uint64 {
	if math.IsNaN(f) {
		return canonicalNaN
	}
	return math.Float64bits(f)
}
