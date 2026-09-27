import { test } from "node:test";
import assert from "node:assert/strict";
import { recordRefund, getRefund } from "../src/refunds.js";

test("a succeeded refund is never downgraded", () => {
  recordRefund({ refundId: "r1", orderNo: "W1", amountPaise: 500, status: "succeeded" });
  recordRefund({ refundId: "r1", orderNo: "W1", amountPaise: 500, status: "pending" });
  assert.equal(getRefund("r1").status, "succeeded");
});
