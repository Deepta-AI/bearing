import { test } from "node:test";
import assert from "node:assert/strict";
import { createStore } from "../src/bookings.js";

test("a slot can be booked once", () => {
  const s = createStore();
  s.book("c1", "2026-10-01T09:00:00Z", "p1");
  assert.throws(() => s.book("c1", "2026-10-01T09:00:00Z", "p2"), /slot taken/);
});

test("a cancelled slot can be booked again", () => {
  const s = createStore();
  const b = s.book("c1", "2026-10-01T09:00:00Z", "p1");
  s.cancel(b.id);
  assert.equal(s.book("c1", "2026-10-01T09:00:00Z", "p2").status, "booked");
});
