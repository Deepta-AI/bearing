import test from "node:test";
import assert from "node:assert/strict";
import { validateEntry } from "../src/ledger.js";
import { handle } from "../src/server.js";

test("a balanced entry is accepted", () => {
  const r = validateEntry({ lines: [{ amountPaise: 1500 }, { amountPaise: -1500 }] });
  assert.equal(r.ok, true);
});

test("an unbalanced entry is refused", () => {
  const r = validateEntry({ lines: [{ amountPaise: 1500 }, { amountPaise: -1400 }] });
  assert.equal(r.ok, false);
});

test("the handler answers 422 for a one-line entry", () => {
  assert.equal(handle({ lines: [{ amountPaise: 0 }] }).status, 422);
});
