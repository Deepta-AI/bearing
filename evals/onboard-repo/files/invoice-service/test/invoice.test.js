import { test } from "node:test";
import assert from "node:assert/strict";
import { invoiceTotals } from "../src/invoice.js";

test("totals for two lines at 18%", () => {
  const t = invoiceTotals(
    [
      { unitPaise: 50000, qty: 2 },
      { unitPaise: 12500, qty: 1 },
    ],
    1800,
  );
  assert.deepEqual(t, { subtotal: 112500, tax: 20250, total: 132750 });
});
