# Security checklist (per release)

1. Every /api/v1 route except the payment webhook requires an API key.
2. Every invoice read is scoped to the caller's tenant.
3. The payment webhook rejects any request without a valid HMAC-SHA256
   signature over the raw body (constant-time compare).
4. Login redirects only to paths on this site.
5. Login is rate limited.
6. API keys are stored hashed, never in plain text.
