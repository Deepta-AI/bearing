# Changelog

## 0.4.2
- Worker: every Razorpay refund call carries the refund id as an
  idempotency key, so a retried call can never refund twice.

## 0.4.1
- The manager-approval limit is read from `config.json`
  (`approval_threshold_paise`) instead of being hard-coded.
- `refunds-bulk` applies the same approval rule as the API.

## 0.4.0
- `refunds-bulk`: load a day's refunds from the desk's CSV export.
