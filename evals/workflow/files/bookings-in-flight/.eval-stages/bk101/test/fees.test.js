import { test } from "node:test";
import assert from "node:assert/strict";
import { cancellationFee } from "../src/fees.js";

test("no fee a day or more ahead", () => {
  assert.equal(cancellationFee("2026-10-02T09:00:00Z", "2026-10-01T09:00:00Z", 20000), 0);
});

test("fee inside 24 hours", () => {
  assert.equal(cancellationFee("2026-10-02T08:00:00Z", "2026-10-01T09:00:00Z", 20000), 20000);
});
