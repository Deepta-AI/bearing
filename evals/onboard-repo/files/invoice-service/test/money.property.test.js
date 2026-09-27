import { test } from "node:test";
import assert from "node:assert/strict";
import { gstPaise } from "../src/money.js";

// Slow on a laptop, so it runs in full only where FULL_PROPERTY_TESTS=1
// (the CI test job sets it).
const full = process.env.FULL_PROPERTY_TESTS === "1";

test(
  "gstPaise rounds half up at every GST rate over 20000 amounts",
  { skip: full ? false : "set FULL_PROPERTY_TESTS=1 (CI does)" },
  () => {
    for (const rate of [0, 500, 1200, 1800, 2800]) {
      for (let amount = 0; amount < 20000; amount++) {
        const exact = BigInt(amount) * BigInt(rate);
        const q = exact / 10000n;
        const want = Number(exact % 10000n >= 5000n ? q + 1n : q);
        assert.equal(gstPaise(amount, rate), want, `amount ${amount} at ${rate} bps`);
      }
    }
  },
);
