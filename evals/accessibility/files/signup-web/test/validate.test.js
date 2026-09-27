import { test } from "node:test";
import assert from "node:assert/strict";
import { validateSignup } from "../src/validate.js";

const ok = { name: "Asha Rao", email: "asha@example.com", password: "correct horse battery", plan: "team", terms: "on" };

test("a complete signup has no errors", () => {
  assert.deepEqual(validateSignup(ok), {});
});

test("every missing field is reported", () => {
  const errors = validateSignup({});
  assert.deepEqual(Object.keys(errors).sort(), ["email", "name", "password", "plan", "terms"]);
});

test("a short password is rejected", () => {
  assert.equal(validateSignup({ ...ok, password: "short" }).password, "Use at least 12 characters");
});
