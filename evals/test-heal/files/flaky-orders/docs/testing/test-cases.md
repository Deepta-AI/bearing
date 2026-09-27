# Test cases: orders

| TC | Story | Title | Expected result |
| --- | --- | --- | --- |
| TC-0201 | US-03-001 | Register a new customer | A new email registers and is given an id. |
| TC-0202 | US-03-002 | Import customers from CSV | Every new row is registered, repeated emails are counted as duplicates and skipped, and the store gains exactly the new customers. |
| TC-0203 | US-05-001 | Receipt after an order | Placing an order sends exactly one receipt for that order, without checkout waiting on the mail provider. |
| TC-0204 | US-04-002 | Best discount wins | When several discounts apply, only the one with the largest percentage is applied: a 3000 rupee order eligible for SAVE10 and BIG15 totals 2550. |
| TC-0205 | US-03-001 | Duplicate email, any case | Registering an email that differs only in case from an existing one fails as a duplicate. |
| TC-0206 | US-03-002 | Import a batch of new customers | A CSV of three new, distinct customers imports all three with no duplicates, and the store gains exactly three. |
