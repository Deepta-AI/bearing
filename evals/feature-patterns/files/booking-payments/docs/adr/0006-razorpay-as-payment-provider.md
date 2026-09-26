# 6. Razorpay as the payment provider

Status: Accepted

## Context

We already bill clinics through Razorpay subscriptions and have a signed
webhook endpoint for it. Patient payments for bookings are next.

## Decision

We will take patient payments with Razorpay Standard Checkout (the
provider's hosted checkout inside the app through its Android SDK), so
card and UPI details never reach our servers. The same webhook endpoint
receives payment events.

## Consequences

Our PCI scope stays at the hosted-checkout level. Razorpay notes that
chargebacks can be raised up to 120 days after a payment is captured.
