# Backlog: payments

## US-05-001 Take a payment (done)

As a merchant, I want to charge a customer so that I get paid.

## US-05-004 Partial refunds (done, shipped in sprint 19)

As a merchant, I want to refund part of a captured payment, as many
times as I need, until the whole amount has been refunded.

- AC-US-05-004-1: A refund can be for any amount up to what is left
  unrefunded on the payment; more than that is refused.
- AC-US-05-004-2: If the dashboard retries a refund request after a
  timeout, the customer is refunded once.
- AC-US-05-004-3: The payment shows how much has been refunded, and its
  status says whether it is partly or fully refunded.
