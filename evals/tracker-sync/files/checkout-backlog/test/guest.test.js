import { test } from "node:test";
import assert from "node:assert/strict";
import { startGuestOrder, findGuestOrder } from "../src/guest.js";

test("guest order needs an email (SHOP-41, AC-1.1)", () => {
  assert.throws(() => startGuestOrder({ email: "", items: [{}] }), /email/);
});

test("guest order lookup matches email case-insensitively (SHOP-42, AC-2.2)", () => {
  const o = { ...startGuestOrder({ email: "Asha@Example.com", items: [{}] }), orderNo: "W1001" };
  assert.equal(findGuestOrder([o], { email: "asha@example.com", orderNo: "W1001" }), o);
  assert.equal(findGuestOrder([o], { email: "asha@example.com", orderNo: "W1002" }), null);
});
