# Backlog: payments

## US-07-001 Order history for support

As a support agent I want to page through a customer's orders so that I
can find the one they are calling about.

- AC-US-07-001-1: orders are listed newest first, 20 per page.

## US-07-002 Partial refunds

As a support agent I want to refund part of a captured order so that a
customer who returns one item gets that item's money back.

- AC-US-07-002-1: a captured order can be refunded in full or in part.
- AC-US-07-002-2: the refunds on an order never add up to more than the
  order total; a refund larger than what is left to refund is rejected
  with `exceeds_refundable`.
- AC-US-07-002-3: a refund of zero or less is rejected with
  `invalid_amount`.
- AC-US-07-002-4: refunds are allowed for 30 days after capture; after
  that they are rejected with `refund_window_closed`.
- AC-US-07-002-5: the customer can download a PDF receipt for a refund.
- AC-US-07-002-6: the money reaches the customer's bank account within
  5 to 7 working days.
- AC-US-07-002-7: every refund publishes `refund.created` with the order
  id, the refund id and the amount, for the ledger.
