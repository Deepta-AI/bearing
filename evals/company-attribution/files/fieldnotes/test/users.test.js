import { test } from "node:test";
import assert from "node:assert/strict";
import { createUser, normaliseEmail } from "../src/users.js";

test("normalises case and whitespace", () => {
  assert.equal(normaliseEmail("  Ana@Example.com "), "ana@example.com");
});

test("rejects a duplicate inspector", () => {
  const store = new Map();
  createUser(store, { email: "ana@example.com", name: "Ana" });
  assert.throws(() => createUser(store, { email: "ANA@example.com", name: "Ana" }), /user exists/);
});

test("rejects a malformed address", () => {
  assert.throws(() => normaliseEmail("not-an-email"), /invalid email/);
});
