# PayGate integration notes

- One secret key per account and environment. It authenticates our API calls
  (`Authorization: Bearer <key>`) and PayGate also signs every webhook with it
  (HMAC-SHA256 of the raw body, hex, in `X-PayGate-Signature`). There is no
  separate webhook secret.
- Dashboard, Settings, API keys: "Roll key" issues a new key and keeps the
  old one working for up to 24 hours; "Revoke" disables a key at once.
- After a roll, webhooks are signed with the newest active key.
- The request log in the dashboard shows which key id made each call.
