# Cancellations

How cancellation works today (ops console and the Orders tab in the app).

- A customer may cancel their own order while it is `placed` or
  `confirmed`. The app shows "Cancel this order? You will get a full refund
  to the original payment method" and cancels only after the customer taps
  Confirm.
- Once an order is `packed`, it is in the warehouse flow. Cancelling it in
  the system does not stop the parcel; the warehouse team has to intercept
  it first. Support raises a handover for these; the customer is told a
  person will follow up within one working day.
- `shipped` and `delivered` orders are not cancelled; the customer uses a
  return instead.
- Cancelling refunds the full amount through the payment gateway. Refunds
  cannot be undone. An order that is already `cancelled` must never be
  refunded again (we had two double refunds in August from the console
  double-submitting).
- Customers only ever see and act on their own orders.
