import { test } from "node:test";
import assert from "node:assert/strict";
import { load, render } from "../src/prompts/index.js";

test("triage v1 renders its ticket text", () => {
  const p = load("triage", 1);
  const out = render(p, { ticket_text: "Where is my parcel?" });
  assert.match(out, /Where is my parcel\?/);
  assert.equal(p.model, "claude-haiku-4-5");
});
