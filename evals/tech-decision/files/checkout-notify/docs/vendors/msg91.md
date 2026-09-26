# MSG91 integration notes

From the support call on 2026-09-15 after INC-231.

- The v2 sendsms endpoint has no idempotency key. Sending the same
  request twice sends two SMS and both are billed.
- A request that times out on our side may still have been accepted and
  delivered. MSG91 cannot tell us afterwards whether a timed-out request
  was accepted unless we have its request_id.
- Every accepted request returns a request_id in the response body.
  Delivery reports (DLR) for it are posted to a webhook we register,
  usually within 2 minutes.
- We do not read the response body today (internal/notify/sms.go), so we
  keep no request_id.
