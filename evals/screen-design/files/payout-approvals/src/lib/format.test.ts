import { test } from "node:test";
import assert from "node:assert/strict";
import { formatINR, formatDate } from "./format.ts";

test("formats paise as rupees with Indian grouping", () => {
  assert.equal(formatINR(1234567), "₹12,345.67");
  assert.equal(formatINR(72500000), "₹7,25,000.00");
  assert.equal(formatINR(0), "₹0.00");
});

test("rejects fractional paise", () => {
  assert.throws(() => formatINR(10.5), TypeError);
});

test("formats dates in IST", () => {
  assert.equal(formatDate("2026-09-18T20:00:00Z"), "19 Sept 2026");
});
