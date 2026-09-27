import { test } from "node:test";
import assert from "node:assert/strict";
import { cartTotal } from "../src/cart.js";

test("cart total adds line totals in paise", () => {
  assert.equal(cartTotal([{ sku: "A", pricePaise: 19900, qty: 2 }, { sku: "B", pricePaise: 500, qty: 1 }]), 40300);
});

test("a zero quantity is rejected", () => {
  assert.throws(() => cartTotal([{ sku: "A", pricePaise: 100, qty: 0 }]), /bad quantity/);
});
