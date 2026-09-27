import { test } from "node:test";
import assert from "node:assert/strict";
import { lineTotal, taxPaise, invoiceTotal } from "../src/rounding.js";

test("line total multiplies in paise", () => {
  assert.equal(lineTotal(1999, 3), 5997);
});

test("tax rounds half up to the paisa", () => {
  assert.equal(taxPaise(1050, 18), 189);
  assert.equal(taxPaise(1, 18), 0);
});

test("invoice total adds tax to the subtotal", () => {
  assert.deepEqual(invoiceTotal([{ unitPaise: 10000, quantity: 2 }], 18), { subtotal: 20000, tax: 3600, total: 23600 });
});

test("negative quantity is refused", () => {
  assert.throws(() => lineTotal(100, -1), RangeError);
});
