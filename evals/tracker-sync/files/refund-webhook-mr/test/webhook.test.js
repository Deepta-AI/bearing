import { test } from "node:test";
import assert from "node:assert/strict";
import { createHmac } from "node:crypto";
import { handleRefundWebhook } from "../src/webhook.js";
import { getRefund } from "../src/refunds.js";

const secret = "test-signing-secret";
const sign = (t, body) => `t=${t},v1=${createHmac("sha256", secret).update(`${t}.${body}`).digest("hex")}`;

test("TC-031 a correctly signed refund.updated event is recorded", () => {
  const body = JSON.stringify({ type: "refund.updated", data: { refundId: "r9", orderNo: "W9", amountPaise: 1200, status: "succeeded" } });
  assert.equal(handleRefundWebhook({ header: sign(1790000000, body), rawBody: body }, secret).status, 200);
  assert.equal(getRefund("r9").status, "succeeded");
});

test("TC-032 an event with a wrong signature is rejected with 401 and not recorded", () => {
  const body = JSON.stringify({ type: "refund.updated", data: { refundId: "r10", orderNo: "W10", amountPaise: 900, status: "succeeded" } });
  const res = handleRefundWebhook({ header: "t=1790000000,v1=" + "0".repeat(64), rawBody: body }, secret);
  assert.equal(res.status, 401);
  assert.equal(getRefund("r10"), null);
});

test.todo("TC-033 a signed event older than 5 minutes is rejected (replay)");
