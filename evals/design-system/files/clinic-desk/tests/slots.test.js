import { test } from "node:test";
import assert from "node:assert/strict";
import { formatSlot, statusLabel } from "../src/lib/slots.js";

test("formatSlot prints start and end in UTC", () => {
  assert.equal(formatSlot("2026-09-01T09:00:00Z", 30), "09:00 to 09:30");
});

test("statusLabel names every status", () => {
  assert.equal(statusLabel("booked"), "Booked");
  assert.equal(statusLabel("checked_in"), "Checked in");
  assert.equal(statusLabel("no_show"), "No show");
  assert.equal(statusLabel("other"), "Unknown");
});
