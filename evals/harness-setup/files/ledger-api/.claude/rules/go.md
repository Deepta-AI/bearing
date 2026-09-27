---
paths:
  - "**/*.go"
---

# Go rules

- Handlers take dependencies through a struct, never package globals.
- Amounts are int64 minor units. Never use float64 for money.
- Every exported function has a doc comment.
- Run `gofmt` on every file you touch.
