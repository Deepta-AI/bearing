# Refund rules

- A refund can never exceed the amount paid on the order.
- Refunds above Rs 5,000 need a manager's approval before they are sent.
  The limit is set in `config.json` (`approval_threshold_paise`), so
  finance can change it without a release.
- The same rules apply to refunds loaded with `refunds-bulk`.
- Approved refunds are sent to Razorpay by the worker every 15 seconds.
