import test from "node:test";
import assert from "node:assert/strict";
import { reverseEntry } from "./reversal.js";
import { balance } from "./ledger.js";

const entry = {
  id: "JE-1001",
  lines: [
    { account: "cash", amountPaise: 2500 },
    { account: "revenue", amountPaise: -2500 },
  ],
};

test("a reversal points at the entry it reverses", () => {
  assert.equal(reverseEntry(entry).reverses, "JE-1001");
});

test("a reversal balances and undoes the original line by line", () => {
  const r = reverseEntry(entry);
  assert.equal(balance(r.lines), 0);
  assert.deepEqual(
    r.lines.map((l) => l.amountPaise),
    entry.lines.map((l) => -l.amountPaise),
  );
});
