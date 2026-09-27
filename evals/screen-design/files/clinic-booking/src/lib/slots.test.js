import { test } from "node:test";
import assert from "node:assert/strict";
import { daySlots, isOpen } from "./slots.js";

test("a weekday has sixteen slots", () => {
  assert.equal(daySlots("2026-10-01").length, 16);
});

test("Sundays and holidays have no slots", () => {
  assert.equal(isOpen("2026-10-04"), false);
  assert.deepEqual(daySlots("2026-10-04"), []);
  assert.deepEqual(daySlots("2026-10-02"), []);
});

test("a fully booked day has no slots", () => {
  const all = daySlots("2026-10-01");
  assert.deepEqual(daySlots("2026-10-01", all), []);
});
