import { test } from "node:test";
import assert from "node:assert/strict";
import { addPaise, gstPaise, formatRupees } from "../src/money.js";

test("addPaise refuses floats", () => {
  assert.throws(() => addPaise(1.5, 1), TypeError);
});

test("gst rounds half up to the paisa", () => {
  assert.equal(gstPaise(1250, 1800), 225);
  assert.equal(gstPaise(1, 5000), 1);
});

test("formatRupees pads paise", () => {
  assert.equal(formatRupees(10005), "Rs 100.05");
  assert.equal(formatRupees(-7), "-Rs 0.07");
});
