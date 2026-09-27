---
paths:
  - "db/migrations/**"
---

# Migration rules

- Never edit a migration that has been applied. 0001 and 0002 are applied in
  every environment. Add a new numbered file instead.
- Every Up has a Down that reverses it.
- New columns on postings are nullable or have a default; the table is large.
