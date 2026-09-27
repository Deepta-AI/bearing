import { test } from "node:test";
import assert from "node:assert/strict";
import { financialYear } from "../src/fiscal.js";

test("an invoice issued at 20:00 UTC on 31 March closes the year", () => {
  assert.equal(financialYear("2026-03-31T20:00:00Z"), "2025-26");
});

test("April opens the next year", () => {
  assert.equal(financialYear("2026-04-15T09:00:00Z"), "2026-27");
});
