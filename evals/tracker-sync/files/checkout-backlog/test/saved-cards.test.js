import { test } from "node:test";
import assert from "node:assert/strict";
import { tokenChargeRequest } from "../src/saved-cards.js";

test("a saved card is charged by its provider token, never a card number (SHOP-66)", () => {
  const req = tokenChargeRequest({ token: "tok_123", brand: "VISA", last4: "4242" }, 40300, "W2001");
  assert.deepEqual(req, { token: "tok_123", amount: 40300, currency: "INR", reference: "W2001" });
});
