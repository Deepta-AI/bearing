# Background jobs

All jobs run on the shared worker. Defaults unless a job says otherwise:

- up to 5 attempts, backoff from 2 s capped at 20 min with full jitter,
  so the chain of retries lasts about an hour;
- after the last attempt the message goes to the dead letter queue;
  on-call replays dead letters within 14 days, after which they are
  archived.

| Job | Trigger | Key |
| --- | --- | --- |
| clinic-invoice-email | subscription.charged webhook | `invoice:<razorpay payment id>` |
