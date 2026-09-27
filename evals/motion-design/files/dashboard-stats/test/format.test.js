import { test } from "node:test";
import assert from "node:assert/strict";
import { formatStat } from "../src/format.js";

test("revenue is rupees with paise, Indian grouping", () => {
  assert.equal(formatStat("revenue", 124500.5), "₹1,24,500.50");
});

test("orders are whole numbers", () => {
  assert.equal(formatStat("orders", 1284), "1,284");
});

test("rates are percentages to one decimal", () => {
  assert.equal(formatStat("refundRate", 0.0213), "2.1%");
});

test("a missing figure reads n/a", () => {
  assert.equal(formatStat("conversion", null), "n/a");
});
