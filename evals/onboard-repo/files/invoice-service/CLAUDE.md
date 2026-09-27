# invoice-service notes for Claude

Node 22 ESM service, no dependencies. Tests: `npm test` (node:test).

## Things Claude gets wrong here

- Money is integer paise. Never introduce a float, a Number division or
  toFixed() on an amount; use src/money.js.
- GST rates are basis points (1800 = 18%), not percentages.
- Migrations under migrations/ are append-only. Never edit an applied one;
  add the next number. The pre-commit hook enforces it.
- Rounding is half up to the paisa in gstPaise; do not "fix" it to banker's
  rounding, the tax office reconciles against this.
