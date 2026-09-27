import { test } from "node:test";
import assert from "node:assert/strict";
import { signupPage } from "../src/views/signup.js";

test("the signup page renders the form", () => {
  const html = signupPage();
  assert.match(html, /<form method="post" action="\/signup"/);
  assert.match(html, /Create account/);
});

test("server-side errors are shown next to the field", () => {
  const html = signupPage({ values: { email: "nope" }, errors: { email: "Enter a valid email address" } });
  assert.match(html, /Enter a valid email address/);
  assert.match(html, /value="nope"/);
});
