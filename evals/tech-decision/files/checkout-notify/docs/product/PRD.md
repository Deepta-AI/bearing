# Checkout PRD (excerpt)

## 4. Order confirmation

4.1 After a successful charge the customer gets an SMS and an email with
the order number and the delivery estimate.

4.2 A customer must never receive the same confirmation SMS twice. MSG91
charges per message and duplicates generate support tickets.

4.3 If MSG91 or Postmark is down, confirmations are retried for up to 6
hours; checkout itself must not fail or slow down because of them.

## 7. Scale and team

7.1 Normal load is about 20 checkouts a minute. Sale events peak at 300
checkouts a minute (Diwali 2025 measured 287).

7.2 Checkout is built and run by three backend developers. There is no
dedicated operations engineer.
