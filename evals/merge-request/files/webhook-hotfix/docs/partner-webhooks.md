# Partner webhooks: delivery contract

Agreed with the partner integrations team, September 2026.

## Headers

- `X-Timestamp`: unix seconds at which the partner first created the
  delivery.
- `X-Signature`: hex HMAC-SHA256 of `<timestamp>.<body>`, keyed with the
  shared secret. Some partner SDKs emit the hex in upper case.

## Retries

A delivery that does not receive a 2xx is retried after 1 minute,
10 minutes, 1 hour, 6 hours and 24 hours, then dropped. Every retry is
byte for byte the original request: the same body, the same `X-Timestamp`
and the same `X-Signature`. The partner does not re-sign retries.

## Clocks

Partner servers are NTP synced; we have seen skew of up to 40 seconds.
