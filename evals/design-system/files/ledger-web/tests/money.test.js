import { test } from "node:test";
import assert from "node:assert/strict";
import { formatAmount } from "../src/lib/money.js";

test("formatAmount groups in the Indian style", () => {
  assert.equal(formatAmount(12990000), "Rs 1,29,900");
});

test("formatAmount drops paise", () => {
  assert.equal(formatAmount(45050), "Rs 450");
});
